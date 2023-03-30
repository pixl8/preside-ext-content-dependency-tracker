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

		lock name="contentDependencyTrackerProcessingLock" type="exclusive" timeout=1 {

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

			var contentRecordIdMap = !_isFullProcessing() ? _getScanningRequiredContentRecordMap()          : {};
			var objectNames        =  _isFullProcessing() ? _getConfiguration().getTrackingEnabledObjects() : structKeyArray( contentRecordIdMap );

			if ( _isFullProcessing() ) {
				_cacheContentRecordData();
			}

			for ( var objectName in objectNames ) {
				_indexContentRecords(
					  objectName = objectName
					, recordIds  = contentRecordIdMap[ objectName ] ?: []
					, logger     = logger
				);
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
			}

			var updated = 0;

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
			}

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
		);
		if ( broken > 0 ) {
			logger.info( "Found [#broken#] orphaned content record(s) that other content records depend on (Broken dependencies). Those have not been deleted." );
		}

		var validObjectNames = _getConfiguration().getTrackingEnabledObjects();

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

		var idField    = $getPresideObjectService().getIdField( objectName );
		var labelField = $getPresideObjectService().getLabelField( objectName );

		var hasCustomLabelGenerator = _getConfiguration().hasCustomLabelGenerator( arguments.objectName );
		var customLabelGenerator    = hasCustomLabelGenerator ? _getConfiguration().getCustomLabelGenerator( arguments.objectName ) : "";

		labelField = len( labelField ) ? labelField : idField;

		var selectFields = [ "#idField# as id", "#labelField# as label" ];
		var filter       = !_isFullProcessing() ? { "#idField#"=arguments.recordIds } : {};

		var records = $getPresideObjectService().selectData( objectName=objectName, filter=filter, selectFields=selectFields );

		logger.info( "Now scanning [#records.recordCount#] [#arguments.objectName#] record(s)..." );

		var updated = 0;
		var label   = "";
		var counter = { inserted=0, updated=0 };

		for ( var record in records ) {
			label = record.label;
			if ( hasCustomLabelGenerator ) {
				label = $renderContent( renderer=customLabelGenerator, data=record.id );
			}
			updated = _getContentRecordDao().updateData(
				  data   = {
					  label                = label
					, orphaned             = false
					, requires_scanning    = true
					, last_scan_process_id = _getProcessId()
					, last_scanned         = _getProcessTimestamp()
				}
				, filter = { object_name=arguments.objectName, record_id=record.id }
			);
			if ( !updated ) {
				_getContentRecordDao().insertData(
					data = {
						  object_name          = arguments.objectName
						, record_id            = record.id
						, label                = label
						, orphaned             = false
						, hidden               = false
						, requires_scanning    = true
						, last_scan_process_id = _getProcessId()
						, last_scanned         = _getProcessTimestamp()
					}
				);
				counter.inserted++;
			}
			else {
				counter.updated++;
			}
		}

		logger.info( "Scanning of [#arguments.objectName#] record(s) completed (inserted: #counter.inserted#, updated: #counter.updated#)" );
	}

	private void function _indexContentRecordDependencies( required string objectName, required array recordIds, any logger ) {

		if ( !_isFullProcessing() && isEmpty( arguments.recordIds ) ) {
			return;
		}

		logger.info( "Now detecting [#arguments.objectName#] object dependencies..." );

		var props = _getConfiguration().getTrackingEnabledObjectProperties( arguments.objectName );

		if ( isEmpty( props ) ) {
			logger.info( "No trackable properties found." );
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

		var filter                  = !_isFullProcessing() ? { "#idField#"=arguments.recordIds } : {};
		var records                 = $getPresideObjectService().selectData( objectName=arguments.objectName, selectFields=selectFields );
		var propName                = "";
		var propValue               = "";
		var sourceRecordId          = "";
		var relatedContentRecordIds = [];
		var upsertResult			= {};
		var counter                 = { inserted=0, updated=0, deleted=0 };

		for ( var record in records ) {
			if ( !_isTrackedContentRecordId( record.id ) ) {
				continue;
			}
			sourceRecordId = _mapContentRecordId( objectName=arguments.objectName, recordId=record.id );
			if ( sourceRecordId == 0 ) {
				continue;
			}
			for ( propName in props ) {
				if ( arrayFindNoCase( skipProperties, propName ) ) {
					continue;
				}
				propValue = record[ propName ];
				if ( isEmpty( propValue ) ) {
					continue;
				}
				if ( props[ propName ].isRelationship ) {
					relatedContentRecordIds = [ propValue ];
					relationTargetObject    = props[ propName ].relatedTo;
					if ( props[ propName ].relationship == "many-to-many" ) {
						relatedContentRecordIds = listToArray( relatedContentRecordIds );
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
			counter.deleted  += _getDependencyDao().deleteData(
				  filter       = "content_record = :content_record and (last_scan_process_id is null or last_scan_process_id != :last_scan_process_id)"
				, filterParams = { content_record=sourceRecordId, last_scan_process_id=_getProcessId() }
			);
		}

		logger.info( "Processing of [#arguments.objectName#] content record dependencies completed (inserted: #counter.inserted#, updated: #counter.updated#, deleted: #counter.deleted#)" );
	}

	private struct function _syncDependencies(
		  required string sourceRecordId
		, required array  targetRecordIds
		, required string objectName
		, required string fieldName
	) {

		var result          = { inserted=0, updated=0, deleted=0 };
		var targetRecordIds = _mapContentRecordIds( recordIds=arguments.targetRecordIds, objectName=arguments.objectName );

		if ( isEmpty( targetRecordIds ) ) {
			return result;
		}

		var updated         = 0;
		var isSoftReference = isEmpty( arguments.objectName ); // soft references have no object name, only hard references do (FKs) - for soft references we just know the UUID

		for ( var targetRecordId in targetRecordIds ) {
			updated = _getDependencyDao().updateData(
				  data   = {
					last_scan_process_id = _getProcessId()
				}
				, filter = {
					  content_record           = arguments.sourceRecordId
					, dependent_content_record = targetRecordId
					, content_record_field     = arguments.fieldName
				}
			);
			if ( !updated ) {
				_getDependencyDao().insertData(
					data = {
						  content_record           = arguments.sourceRecordId
						, dependent_content_record = targetRecordId
						, content_record_field     = arguments.fieldName
						, is_soft_reference        = isSoftReference
						, last_scan_process_id     = _getProcessId()
					}
				);
				result.inserted++;
			}
			else {
				result.updated++;
			}
		}

		return result;
	}

	private any function _getTrackedContentRecordIds() {
		return _simpleLocalCache( "getTrackedContentRecordIds", function() {

			var records  = _getContentRecordDao().selectData( selectFields=[ "record_id" ], distinct=true );
			var result = createObject( "java", "java.util.HashSet" ).init();

			if ( records.recordCount ) {
				result.addAll( queryColumnData( records, "record_id" ) );
			}

			return result;
		} );
	}

	private struct function _getMappedContentRecordIds() {
		return _simpleLocalCache( "getMappedContentRecordIds", function() {

			var records = _getContentRecordDao().selectData( selectFields=[ "record_id", "object_name", "id" ] );
			var result  = {};

			loop query="records" {
				result[ "#records.object_name#_#records.record_id#" ] = records.id;
			}

			return result;
		} );
	}

	private numeric function _mapContentRecordId( required string objectName, required string recordId ) {

		if ( _isFullProcessing() ) {
			var mappings = _getMappedContentRecordIds();
			return mappings[ arguments.objectName & "_" & arguments.recordId ] ?: 0;
		}

		return getContentRecordId( arguments.objectName, arguments.recordId );
	}

	private array function _mapContentRecordIds( required array recordIds, string objectName="" ) {
		var mappedId = 0;
		var result   = [];
		var type     = "";

		// either a content type is supplied or it's unknown and therefore we need to consider all content types
		var objectNames = len( arguments.objectName ) ? [ arguments.objectName ] : _getConfiguration().getTrackingEnabledObjects();

		for ( var recordId in arguments.recordIds ) {
			
			if ( !_isTrackedContentRecordId( recordId ) ) {
				continue;
			}

			for ( type in objectNames ) {
				mappedId = _mapContentRecordId( objectName=type, recordId=recordId );
				if ( mappedId > 0 ) {
					arrayAppend( result, mappedId );
				}
			}
		}

		return result;
	}

	private boolean function _isTrackedContentRecordId( required any recordId ) {
		if ( _isFullProcessing() ) {
			return _getTrackedContentRecordIds().contains( arguments.recordId );
		}
		return _getContentRecordDao().dataExists( filter={ record_id=arguments.recordId } );
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

	private struct function _getScanningRequiredContentRecordMap() {
		var records = _getContentRecordDao().selectData(
			  filter       = { requires_scanning=true }
			, selectFields = [ "object_name", "record_id" ]
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