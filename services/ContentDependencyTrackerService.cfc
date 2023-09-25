/**
* @singleton      true
* @presideService true
*/
component {

// CONSTRUCTOR
	/**
     * @contentRecordDao.inject presidecms:object:tracked_content_record
     * @dependencyDao.inject    presidecms:object:tracked_content_record_dependency
     * @configuration.inject    contentDependencyTrackerConfigurationService
     */
	public any function init(
		  required any contentRecordDao
		, required any dependencyDao
		, required any configuration
	) {

		_setContentRecordDao( arguments.contentRecordDao );
		_setDependencyDao( arguments.dependencyDao );
		_setConfiguration( arguments.configuration );

		_setLocalCache( {} );

		return this;
	}

// PUBLIC FUNCTIONS
	public boolean function scanContentDependencies( required boolean full, any logger ) {

		lock name="contentDependencyTrackerProcessingLock" type="exclusive" timeout=30 {

			if ( !_getConfiguration().isEnabled() ) {
				logger.warn( "Tracking is disabled, aborting. Please enable in system settings." );
				return false;
			}

			var isForeignKeyScanningEnabled    = _getConfiguration().isForeignKeyScanningEnabled();
			var isSoftReferenceScanningEnabled = _getConfiguration().isSoftReferenceScanningEnabled();

			if ( !isForeignKeyScanningEnabled && !isSoftReferenceScanningEnabled ) {
				logger.warn( "Tracking is enabled but neither hard nor soft reference scanning is, aborting. Please enable at least one of those (or both) in system settings." );
				return false;
			}

			_setFullProcessing( arguments.full );
			_setProcessId( createUUID() );
			_setProcessTimestamp( now() );

			logger.info( "Now scanning content records to track dependencies (Process ID: #_getProcessId()#, Full: #arguments.full#, FK Scanning enabled: #isForeignKeyScanningEnabled#, Soft Reference Scanning enabled: #isSoftReferenceScanningEnabled#)..." );

			var contentRecordIdMap = {};
			var objectNames        = _getConfiguration().getAllTrackableObjects();

			if ( !_isFullProcessing() ) {
				var overallRecordCount = _getScanningRequiredContentRecordCount();

				logger.info( "Number of records requiring scanning: #overallRecordCount#" );

				var batchSize = _getConfiguration().getDeltaScanningBatchSize();

				if ( overallRecordCount > 0 && batchSize > 0 && batchSize < overallRecordCount ) {
					logger.info( "Batch size: #batchSize# (this is the maximum number of records processed in this task run)" );
				}

				contentRecordIdMap = _getBatchedScanningRequiredContentRecordMap( batchSize=batchSize );
				objectNames        = structKeyArray( contentRecordIdMap );
			}

			_cacheContentRecordData();

			for ( var objectName in objectNames ) {
				_indexContentRecords(
					  objectName = objectName
					, recordIds  = contentRecordIdMap[ objectName ] ?: []
					, logger     = logger
				);
				if ( $isInterrupted() ) {
					logger.warn( "Operation was cancelled or interrupted. Safely quitting..." );
					return false;
				}
			}

			if ( _isFullProcessing() ) {
				var orphaned = _getContentRecordDao().updateData(
					  data         = { orphaned=true }
					, filter       = "orphaned = :orphaned and (last_scan_process_id is null or last_scan_process_id != :last_scan_process_id)"
					, filterParams = { orphaned=false, last_scan_process_id=_getProcessId() }
				);
				if ( orphaned > 0 ) {
					logger.info( "marked [#orphaned#] non-orphaned content record(s) as orphaned because not found during processing." );
				}
			}

			for ( var objectName in objectNames ) {
				_indexContentRecordDependencies(
					  objectName = objectName
					, recordIds  = contentRecordIdMap[ objectName ] ?: []
					, logger     = logger
				);
				if ( $isInterrupted() ) {
					logger.warn( "Operation was cancelled or interrupted. Safely quitting..." );
					return false;
				}
			}

			var updated = 0;

			// flag irrelevant records as hidden
			for ( var objectName in objectNames ) {
				if ( !_getConfiguration().hideAllIrrelevantContentRecords() && !_getConfiguration().hideIrrelevantRecords( objectName ) ) {
					continue;
				}
				updated = _getContentRecordDao().updateData(
					  filter          = "object_name = :object_name and (hidden is null or hidden = :hidden) and last_scan_process_id = :last_scan_process_id and not exists (select 1 from pobj_tracked_content_record_dependency d where d.content_record = tracked_content_record.id or d.dependent_content_record = tracked_content_record.id)"
					, filterParams    = { object_name=objectName, last_scan_process_id=_getProcessId(), hidden=false }
					, data            = { hidden=true }
					, setDateModified = false
				);
				if ( updated > 0 ) {
					logger.info( "hiding [#updated#] [#objectName#] record(s) without dependencies" );
				}
				if ( $isInterrupted() ) {
					logger.warn( "Operation was cancelled or interrupted. Safely quitting..." );
					return false;
				}
			}

			// remove scan flag from records that have been processed in this run
			updated = _getContentRecordDao().updateData(
				  filter          = { requires_scanning=true, last_scan_process_id=_getProcessId() }
				, data            = { requires_scanning=false }
				, setDateModified = false
			);
			if ( updated > 0 ) {
				logger.info( "Marked [#updated#] scanned content record(s) to not require scanning anymore (processed within this run)." );
			}

			// deal with orphaned content records
			updated = _getContentRecordDao().updateData(
				  filter          = { requires_scanning=true, orphaned=true }
				, data            = { requires_scanning=false, last_scan_process_id=_getProcessId(), last_scanned=_getProcessTimestamp() }
				, setDateModified = false
			);
			if ( updated > 0 ) {
				logger.info( "Marked [#updated#] orphaned content record(s) to not require scanning anymore." );
			}

			deleted = _getDependencyDao().deleteData(
				  filter       = "content_record in (select id from pobj_tracked_content_record where orphaned = :tracked_content_record.orphaned and last_scan_process_id = :tracked_content_record.last_scan_process_id)"
				, filterParams = { "tracked_content_record.orphaned"=true, "tracked_content_record.last_scan_process_id"=_getProcessId() }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] dependencies of orphaned content records." );
			}

			_clearCachedContentRecordData();

			logger.info( "Done." );

			return true;
		}
	}

	public void function removeOrphanedContentRecords( any logger ) {
		logger.info( "Now removing all content records that are flagged as orphaned..." );

		_getDependencyDao().deleteData(
			  filter       = "content_record in (select id from pobj_tracked_content_record where orphaned = :tracked_content_record.orphaned)"
			, filterParams = { "tracked_content_record.orphaned"=true }
		);

		var deleted = _getContentRecordDao().deleteData(
			  filter       = "orphaned = :orphaned and not exists (select 1 from pobj_tracked_content_record_dependency d where d.content_record = tracked_content_record.id or d.dependent_content_record = tracked_content_record.id)"
			, filterParams = { orphaned=true }
		);
		if ( deleted > 0 ) {
			logger.info( "Removed [#deleted#] orphaned content record(s) that have no dependencies anymore" );
		}
		else {
			logger.info( "Nothing to delete." );
		}

		var broken = _getContentRecordDao().selectData(
			  filter          = "orphaned = :orphaned and exists (select 1 from pobj_tracked_content_record_dependency d where d.content_record = tracked_content_record.id or d.dependent_content_record = tracked_content_record.id)"
			, filterParams    = { orphaned=true }
			, recordCountOnly = true
			, useCache        = false
		);
		if ( broken > 0 ) {
			logger.info( "Found [#broken#] orphaned content record(s) that other content records depend on (Broken dependencies). Those have not been deleted." );
		}

		var validObjectNames = _getConfiguration().getAllTrackableObjects();

		if ( !isEmpty( validObjectNames ) ) {
			deleted = _getDependencyDao().deleteData(
				  filter       = "content_record.object_name not in (:validObjectNames) or dependent_content_record.object_name not in (:validObjectNames)"
				, filterParams = { validObjectNames={ value=validObjectNames, type="cf_sql_varchar", list=true } }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] dependency record(s) which belong(s) to content records that are not tracked (anymore)" );
			}
			deleted = _getContentRecordDao().deleteData(
				  filter       = "object_name not in (:validObjectNames)"
				, filterParams = { validObjectNames={ value=validObjectNames, type="cf_sql_varchar", list=true } }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] content record(s) that is/are not tracked (anymore)" );
			}
		}

		logger.info( "Done." );
	}

	public numeric function getContentRecordId( required string objectName, required string recordId ) {
		var records = _getContentRecordDao().selectData(
			  filter       = { object_name=arguments.objectName, record_id=arguments.recordId }
			, selectFields = [ "id" ]
			, useCache     = false
		);

		for ( var record in records ) {
			return record.id;
		}

		return 0;
	}

	public struct function getContentRecord( required string objectName, required string recordId ) {
		var records = _getContentRecordDao().selectData(
			  filter       = { object_name=arguments.objectName, record_id=arguments.recordId }
			, selectFields = [ "id", "label", "depends_on_count", "dependent_by_count" ]
			, useCache     = false
		);

		for ( var record in records ) {
			return record;
		}

		return {};
	}

	public void function createContentRecord( required string objectName, required string id ) {
		// the label will be added later during the actual scanning
		_getContentRecordDao().insertData(
			data = {
				  object_name       = arguments.objectName
				, record_id         = arguments.id
				, label             = "tmp-" & arguments.id
				, orphaned          = false
				, hidden            = false
				, requires_scanning = true
			}
		);
	}

	public void function flagContentRecordForScanning( required string objectName, required string id ) {
		_getContentRecordDao().updateData(
			  data   = { requires_scanning=true }
			, filter = { object_name=arguments.objectName, record_id=arguments.id }
		);
	}

	public void function flagContentRecordsDeleted( required string objectName, required array ids ) {
		_getContentRecordDao().updateData(
			  data   = { orphaned=true, requires_scanning=true }
			, filter = { object_name=arguments.objectName, record_id=arguments.ids }
		);
	}

	public struct function detectContentRecordByRequestContext( required any rc ) {

		var eventName = trim( arguments.rc.event ?: "" );

		if ( isEmpty( eventName ) ) {
			return {};
		}

		var linkToTrackerEvents = _getConfiguration().getLinkToTrackerEventConfig();

		if ( !structKeyExists( linkToTrackerEvents, eventName ) ) {
			return {};
		}

		var linkToTrackerEvent = linkToTrackerEvents[ eventName ];
		var objectName         = linkToTrackerEvent.objectName      ?: "";
		var objectNameParam    = linkToTrackerEvent.objectNameParam ?: "";
		var recordIdParam      = linkToTrackerEvent.recordIdParam   ?: "";
		var recordId           = "";

		if ( isEmpty( objectName ) && !isEmpty( objectNameParam ) ) {
			objectName = arguments.rc[ objectNameParam ] ?: "";
		}
		if ( !isEmpty( recordIdParam ) ) {
			recordId = arguments.rc[ recordIdParam ] ?: "";
		}
		if ( isEmpty( objectName ) && isEmpty( recordId ) ) {
			return {};
		}

		// TODO: maybe add support for custom detectors? (additional annotation on object level)

		if ( !_getConfiguration().isTrackingEnabledObject( objectName ) ) {
			return {};
		}

		return getContentRecord( objectName, recordId );
	}

// PRIVATE FUNCTIONS
	private void function _indexContentRecords( required string objectName, required array recordIds, any logger ) {

		if ( !_isFullProcessing() && isEmpty( arguments.recordIds ) ) {
			return;
		}

		var idField                = $getPresideObjectService().getIdField( arguments.objectName );
		var labelField             = $getPresideObjectService().getLabelField( arguments.objectName );
		var labelFieldColumnExists = $getPresideObjectService().fieldExists( arguments.objectName, labelField );

		var hasCustomLabelGenerator = _getConfiguration().hasCustomLabelGenerator( arguments.objectName );
		var customLabelGenerator    = hasCustomLabelGenerator ? _getConfiguration().getCustomLabelGenerator( arguments.objectName ) : "";

		labelField = ( len( labelField ) && labelFieldColumnExists ) ? labelField : idField;

		var selectFields = [ "#idField# as id", "#labelField# as label" ];
		var filter       = !_isFullProcessing() ? { "#idField#"=arguments.recordIds } : {};

		var q = $getPresideObjectService().selectData( objectName=arguments.objectName, filter=filter, selectFields=selectFields, useCache=false );

		var counter                   = { inserted=0, updated=0, unchanged=0 };
		var data                      = {};
		var trackedContentRecordId    = 0;
		var unchangedContentRecordIds = [];

		var labelAndOrphanedMaps = _getRecordLabelAndOrphanedMaps( objectName=arguments.objectName, recordIds=arguments.recordIds );
		var recordLabels         = labelAndOrphanedMaps.labels;
		var orphanedMap          = labelAndOrphanedMaps.orphaned;

		loop query="q" {
			data = {
				  label                = hasCustomLabelGenerator ? $renderContent( renderer=customLabelGenerator, data=q.id ) : trim( q.label )
				, orphaned             = false
				, requires_scanning    = true
				, last_scan_process_id = _getProcessId()
				, last_scanned         = _getProcessTimestamp()
			};

			if ( isEmpty( data.label ) ) {
				data.label = q.id;
			}

			data.label = left( data.label, 400 );

			if ( _mappedContentRecordExists( recordId=q.id, objectName=arguments.objectName ) ) {
				trackedContentRecordId = _mapContentRecordId( recordId=q.id, objectName=arguments.objectName );
				if ( orphanedMap[ trackedContentRecordId ] || ( recordLabels[ trackedContentRecordId ] != data.label ) ) {
					_getContentRecordDao().updateData(
						  data   = data
						, filter = { id=trackedContentRecordId }
					);
					counter.updated++;
				}
				else {
					arrayAppend( unchangedContentRecordIds, trackedContentRecordId );
				}
			}
			else {

				data.object_name = arguments.objectName;
				data.record_id   = q.id;
				data.hidden	     = false;

				trackedContentRecordId = _getContentRecordDao().insertData( data=data );
				_addTrackedContentRecordId( q.id );
				_addMappedContentRecordId( objectName=arguments.objectName, recordId=q.id, mappedId=trackedContentRecordId );
				counter.inserted++;
			}
		}

		if ( arrayLen( unchangedContentRecordIds ) > 0 ) {
			counter.unchanged = _getContentRecordDao().updateData(
				  data   = {
					  orphaned             = false
					, requires_scanning    = true
					, last_scan_process_id = _getProcessId()
					, last_scanned         = _getProcessTimestamp()
				}
				, filter = { id=unchangedContentRecordIds }
			);
		}

		logger.info( "Scanning of [#arguments.objectName#] records completed (inserted: #counter.inserted#, updated: #counter.updated#, unchanged:#counter.unchanged#)" );
	}

	private struct function _getRecordLabelAndOrphanedMaps( required string objectName, required array recordIds ) {
		var filter = { object_name=arguments.objectName };

		if ( !_isFullProcessing() ) {
			filter[ "record_id" ] = arguments.recordIds;
		}

		var q      = _getContentRecordDao().selectData( selectFields=[ "id", "label", "orphaned" ], filter=filter, useCache=false );
		var result = { labels={}, orphaned={} };

		loop query="q" {
			result.labels[ q.id ]    = q.label;
			result.orphaned[ q.id ]  = q.orphaned;
		}

		return result;
	}

	private void function _indexContentRecordDependencies( required string objectName, required array recordIds, any logger ) {

		if ( !_isFullProcessing() && isEmpty( arguments.recordIds ) ) {
			return;
		}

		var props = _getConfiguration().getTrackingEnabledObjectProperties( arguments.objectName );

		if ( isEmpty( props ) ) {
			return;
		}

		var isForeignKeyScanningEnabled    = _getConfiguration().isForeignKeyScanningEnabled();
		var isSoftReferenceScanningEnabled = _getConfiguration().isSoftReferenceScanningEnabled();

		var selectFields   = [];
		var skipProperties = []; // not enabled for tracking

		for ( var propName in props ) {
			if (   (  props[ propName ].isRelationship && !isForeignKeyScanningEnabled    )
				|| ( !props[ propName ].isRelationship && !isSoftReferenceScanningEnabled )
			) {
				arrayAppend( skipProperties, propName );
				continue;
			}
			if ( props[ propName ].isRelationship && props[ propName ].relationship == "many-to-many" ) {
				var relatedObjectIdField = $getPresideObjectService().getIdField( props[ propName ].relatedTo );
				arrayAppend( selectFields, "GROUP_CONCAT( DISTINCT #propName#.#relatedObjectIdField# ) AS #propName#" );
			}
			else {
				arrayAppend( selectFields, propName );
			}
		}

		var idField = $getPresideObjectService().getIdField( objectName );

		arrayAppend( selectFields, idField );

		var filter                   = !_isFullProcessing() ? { "#idField#"=arguments.recordIds } : {};
		var q                        = $getPresideObjectService().selectData( objectName=arguments.objectName, selectFields=selectFields, filter=filter, autoGroupBy=true, useCache=false );
		var propName                 = "";
		var propValue                = "";
		var sourceRecordId           = "";
		var relatedContentRecordIds  = [];
		var processedSourceRecordIds = [];
		var upsertResult			 = {};
		var counter                  = { inserted=0, updated=0, deleted=0 };

		loop query="q" {
			if ( !_mappedContentRecordExists( recordId=q.id, objectName=arguments.objectName ) ) {
				continue;
			}
			sourceRecordId = _mapContentRecordId( objectName=arguments.objectName, recordId=q.id );
			if ( sourceRecordId == 0 ) {
				continue;
			}
			for ( propName in props ) {
				if ( arrayFindNoCase( skipProperties, propName ) ) {
					continue;
				}
				propValue = queryGetCell( q, propName, q.currentRow );
				if ( isEmpty( propValue ) ) {
					continue;
				}
				if ( props[ propName ].isRelationship ) {
					relatedContentRecordIds = [ propValue ];
					relationTargetObject    = props[ propName ].relatedTo;
					if ( props[ propName ].relationship == "many-to-many" ) {
						relatedContentRecordIds = listToArray( propValue );
					}
				}
				else {
					// soft references
					relatedContentRecordIds = _findUuids( propValue );
					relationTargetObject    = "";
				}
				upsertResult = _syncDependencies(
					  sourceRecordId  = sourceRecordId
					, targetRecordIds = relatedContentRecordIds
					, objectName      = relationTargetObject
					, fieldName       = propName
				);
				counter.updated  += upsertResult.updated;
				counter.inserted += upsertResult.inserted;
			}
			arrayAppend( processedSourceRecordIds, sourceRecordId );
			if ( arrayLen( processedSourceRecordIds ) > 100 ) {
				counter.deleted += _deleteOrphanedDependencies( processedSourceRecordIds );
				arrayClear( processedSourceRecordIds );
			}
		}

		if ( arrayLen( processedSourceRecordIds ) > 0 ) {
			counter.deleted += _deleteOrphanedDependencies( processedSourceRecordIds );
		}

		logger.info( "Processing of [#arguments.objectName#] content record dependencies completed (inserted: #counter.inserted#, updated: #counter.updated#, deleted: #counter.deleted#)" );
	}

	private numeric function _deleteOrphanedDependencies( required array sourceRecordIds ) {
		return _getDependencyDao().deleteData(
			  filter       = "content_record in (:content_record) and (last_scan_process_id is null or last_scan_process_id != :last_scan_process_id)"
			, filterParams = { content_record=arguments.sourceRecordIds, last_scan_process_id=_getProcessId() }
		);
	}

	private struct function _syncDependencies(
		  required string sourceRecordId
		, required array  targetRecordIds
		, required string objectName
		, required string fieldName
	) {

		var result                    = { inserted=0, updated=0 };
		var mappedTargetRecordIds     = _mapContentRecordIds( recordIds=arguments.targetRecordIds, objectName=arguments.objectName );
		var mappedTargetRecordIdCount = arrayLen( mappedTargetRecordIds );

		if ( mappedTargetRecordIdCount == 0 ) {
			return result;
		}

		var isSoftReference = isEmpty( arguments.objectName ); // soft references have no object name, only hard references do (FKs) - for soft references we just know the UUID

		result.updated = _getDependencyDao().updateData(
			  data   = {
				last_scan_process_id = _getProcessId()
			}
			, filter = {
				  content_record           = arguments.sourceRecordId
				, content_record_field     = arguments.fieldName
				, dependent_content_record = mappedTargetRecordIds
			}
		);

		if ( mappedTargetRecordIdCount > result.updated ) {
			_executePlainQuery( sql="
				INSERT INTO pobj_tracked_content_record_dependency (
					  content_record
					, dependent_content_record
					, content_record_field
					, is_soft_reference
					, last_scan_process_id
					, datecreated
					, datemodified
				)
				SELECT
					  :sourceRecordId
					, tcr.id
					, :fieldName
					, :isSoftReference
					, :processId
					, :datecreated
					, :datecreated
				FROM
					pobj_tracked_content_record tcr
				WHERE
					tcr.id IN (:targetRecordIds)
					AND NOT EXISTS (
						SELECT
							1
						FROM
							pobj_tracked_content_record_dependency
						WHERE
							dependent_content_record = tcr.id
							AND content_record       = :sourceRecordId
							AND content_record_field = :fieldName
					)
				"
				, params = {
					  sourceRecordId  = { value=arguments.sourceRecordId, cfsqltype="cf_sql_bigint"            }
					, fieldName       = { value=arguments.fieldName     , cfsqltype="cf_sql_varchar"           }
					, targetRecordIds = { value=mappedTargetRecordIds   , cfsqltype="cf_sql_bigint", list=true }
					, isSoftReference = { value=isSoftReference         , cfsqltype="cf_sql_bit"               }
					, processId       = { value=_getProcessId()         , cfsqltype="cf_sql_varchar"           }
					, datecreated     = { value=now()                   , cfsqltype="cf_sql_date"              }
				}
			);

			result.inserted = arrayLen( mappedTargetRecordIds ) - result.updated;
		}

		return result;
	}

	private any function _getTrackedContentRecordIds() {
		return _simpleLocalCache( "getTrackedContentRecordIds", function() {

			var records  = _getContentRecordDao().selectData( selectFields=[ "record_id" ], distinct=true, useCache=false );
			var result = createObject( "java", "java.util.HashSet" ).init();

			if ( records.recordCount ) {
				result.addAll( queryColumnData( records, "record_id" ) );
			}

			return result;
		} );
	}

	private boolean function _isTrackedContentRecordId( required any recordId ) {
		return _getTrackedContentRecordIds().contains( arguments.recordId );
	}

	private void function _addTrackedContentRecordId( required string recordId ) {
		var trackedContentRecordIds = _getTrackedContentRecordIds();
		trackedContentRecordIds.add( arguments.recordId );
	}

	private struct function _getMappedContentRecordIds() {
		return _simpleLocalCache( "getMappedContentRecordIds", function() {

			var records = _getContentRecordDao().selectData( selectFields=[ "record_id", "object_name", "id" ], useCache=false );
			var result  = {};

			loop query="records" {
				result[ "#records.object_name#_#records.record_id#" ] = records.id;
			}

			return result;
		} );
	}

	private void function _addMappedContentRecordId( required string objectName, required string recordId, required numeric mappedId ) {
		var mappedContentRecordIds = _getMappedContentRecordIds();
		mappedContentRecordIds[ arguments.objectName & "_" & arguments.recordId ] = arguments.mappedId;
	}

	private numeric function _mapContentRecordId( required string objectName, required string recordId ) {
		var mappings = _getMappedContentRecordIds();
		return mappings[ arguments.objectName & "_" & arguments.recordId ] ?: 0;
	}

	private array function _mapContentRecordIds( required array recordIds, string objectName="" ) {

		var result = [];

		if ( len( arguments.objectName ) ) {
			for ( var recordId in arguments.recordIds ) {
				if ( _mappedContentRecordExists( recordId=recordId, objectName=arguments.objectName ) ) {
					arrayAppend( result, _mapContentRecordId( objectName=arguments.objectName, recordId=recordId ) );
				}
			}
			return result;
		}

		// either a content type is supplied or it's unknown and therefore we need to consider all content types
		var objectNames = _getConfiguration().getAllTrackableObjects();
		var type        = "";
		
		for ( var recordId in arguments.recordIds ) {
			
			if ( !_isTrackedContentRecordId( recordId ) ) {
				continue;
			}

			for ( type in objectNames ) {
				if ( _mappedContentRecordExists( recordId=recordId, objectName=type ) ) {
					arrayAppend( result, _mapContentRecordId( objectName=type, recordId=recordId ) );
				}
			}
		}

		return result;
	}

	private boolean function _mappedContentRecordExists( required string objectName, required string recordId ) {
		return structKeyExists( _getMappedContentRecordIds(), arguments.objectName & "_" & arguments.recordId );
	}

	private void function _cacheContentRecordData() {
		_clearCachedContentRecordData();
		_getTrackedContentRecordIds();
		_getMappedContentRecordIds();
	}

	private void function _clearCachedContentRecordData() {
		structDelete( _getLocalCache(), "getTrackedContentRecordIds" );
		structDelete( _getLocalCache(), "getMappedContentRecordIds" );
	}

	private array function _findUuids( required string content ) {
		// this will find plain UUIDs, but also those that have been url encoded one or more times (this is the case in rich editor content with nested widgets)
		var plainOrUrlEncodedUuidRegexPattern = "[0-9a-fA-F]{8}(-|%(25)*2D)[0-9a-fA-F]{4}(-|%(25)*2D)[0-9a-fA-F]{4}(-|%(25)*2D)[0-9a-fA-F]{16}";
		var urlEncodedHivenRegexPattern = "%(25)*2D";

		var matches = reMatch( plainOrUrlEncodedUuidRegexPattern, arguments.content );

		var result = [];

		for ( var match in matches ) {
			match = uCase( match );
			match = reReplace( match, urlEncodedHivenRegexPattern, "-", "all" );

			if ( !arrayContains( result, match ) ) {
				arrayAppend( result, match );
			}
		}

		return result;
	}

	private struct function _getBatchedScanningRequiredContentRecordMap( numeric batchSize=_getConfiguration().getDeltaScanningBatchSize() ) {
		var records = _getContentRecordDao().selectData(
			  filter       = { requires_scanning=true }
			, selectFields = [ "object_name", "record_id" ]
			, orderby      = "datemodified"
			, maxRows      = arguments.batchSize
			, useCache     = false
		);

		var result = {};

		loop query="records" {
			if ( !structKeyExists( result, records.object_name ) ) {
				result[ records.object_name ] = [];
			}
			arrayAppend( result[ records.object_name ], records.record_id );
		}

		return result;
	}

	private numeric function _getScanningRequiredContentRecordCount() {
		return _getContentRecordDao().selectData(
			  filter          = { requires_scanning=true }
			, recordCountOnly = true
			, useCache        = false
		);
	}

	private any function _simpleLocalCache( required string cacheKey, required any generator ) {
		var cache = _getLocalCache();

		if ( !cache.keyExists( cacheKey ) ) {
			cache[ cacheKey ] = generator();
		}

		return cache[ cacheKey ] ?: NullValue();
	}

	private boolean function _isFullProcessing() {
		return _getFullProcessing();
	}

	private any function _executePlainQuery( required string sql, struct params={} ) {

		var q = new Query();

		q.setDatasource( "preside" );

		for ( var fieldName in arguments.params ) {
			arguments.params[ fieldName ].name = fieldName;
			q.addParam( argumentCollection=arguments.params[ fieldName ] );
		}

		q.setSQL( arguments.sql );

		return q.execute().getResult();
	}

// GETTERS AND SETTERS
	private any function _getContentRecordDao() {
		return _contentRecordDao;
	}
	private void function _setContentRecordDao( required any contentRecordDao ) {
		_contentRecordDao = arguments.contentRecordDao;
	}

	private any function _getDependencyDao() {
		return _dependencyDao;
	}
	private void function _setDependencyDao( required any dependencyDao ) {
		_dependencyDao = arguments.dependencyDao;
	}

	private any function _getConfiguration() {
		return _configuration;
	}
	private void function _setConfiguration( required any configuration ) {
		_configuration = arguments.configuration;
	}

	private struct function _getLocalCache() {
		return _localCache;
	}
	private void function _setLocalCache( required struct localCache ) {
		_localCache = arguments.localCache;
	}

	private boolean function _getFullProcessing() {
		return _fullProcessing;
	}
	private void function _setFullProcessing( required boolean fullProcessing ) {
		_fullProcessing = arguments.fullProcessing;
	}

	private string function _getProcessId() {
		return _processId;
	}
	private void function _setProcessId( required string processId ) {
		_processId = arguments.processId;
	}

	private date function _getProcessTimestamp() {
		return _processTimestamp;
	}
	private void function _setProcessTimestamp( required date processTimestamp ) {
		_processTimestamp = arguments.processTimestamp;
	}
}