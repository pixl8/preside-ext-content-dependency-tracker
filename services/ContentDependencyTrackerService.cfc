/**
* @singleton      true
* @presideService true
*/
component {

// CONSTRUCTOR
	/**
     * @presideObjectService.inject presideObjectService
     * @contentObjectDao.inject     presidecms:object:tracked_content_object
     * @dependencyDao.inject        presidecms:object:tracked_content_object_dependency
     * @settings.inject             coldbox:setting:contentDependencyTracker
     */
	public any function init(
		  required any presideObjectService
		, required any contentObjectDao
		, required any dependencyDao
		, required any settings
	) {

		_setPresideObjectService( arguments.presideObjectService );
		_setContentObjectDao( arguments.contentObjectDao );
		_setDependencyDao( arguments.dependencyDao );
		_setSettings( arguments.settings );

		_setLocalCache( {} );

		return this;
	}

// PUBLIC FUNCTIONS
	public boolean function scanContentDependencies( required boolean full, any logger ) {

		lock name="contentDependencyTrackerProcessingLock" type="exclusive" timeout=1 {

			_setFullProcessing( arguments.full );
			_setProcessId( createUUID() );
			_setProcessTimestamp( now() );

			logger.info( "Now scanning content objects to track dependencies (Process ID: #_getProcessId()#, Full: #arguments.full#)..." );

			if ( !isEnabled() ) {
				logger.warn( "Tracking is disabled, aborting. Please enable in system settings." );
				return false;
			}

			var isForeignKeyScanningEnabled    = _isForeignKeyScanningEnabled();
			var isSoftReferenceScanningEnabled = _isSoftReferenceScanningEnabled();

			if ( !isForeignKeyScanningEnabled && !isSoftReferenceScanningEnabled ) {
				logger.warn( "Tracking is enabled but neither hard nor soft reference scanning is, aborting. Please enable at least one of those (or both) in system settings." );
				return false;
			}

			var contentObjectIdMap = !_isFullProcessing() ? _getScanningRequiredContentObjectMap() : {};
			var objectNames        =  _isFullProcessing() ? _getTrackingEnabledObjects()           : structKeyArray( contentObjectIdMap );

			if ( _isFullProcessing() ) {
				_cacheContentObjectData();
			}

			for ( var objectName in objectNames ) {
				_indexContentObjects(
					  objectName = objectName
					, contentIds = contentObjectIdMap[ objectName ] ?: []
					, logger     = logger
				);
			}

			if ( _isFullProcessing() ) {
				var orphaned = _getContentObjectDao().updateData(
					  data         = { orphaned=true }
					, filter       = "orphaned = :orphaned and (last_scan_process_id is null or last_scan_process_id != :last_scan_process_id)"
					, filterParams = { orphaned=false, last_scan_process_id=_getProcessId() }
				);
				if ( orphaned > 0 ) {
					logger.info( "marked [#orphaned#] non-orphaned content object(s) as orphaned because not found during processing." );
				}
			}

			for ( var objectName in objectNames ) {
				_indexContentObjectDependencies(
					  objectName = objectName
					, contentIds = contentObjectIdMap[ objectName ] ?: []
					, logger     = logger
				);
			}

			var updated = 0;

			for ( var objectName in objectNames ) {
				if ( !_hideAllIrrelevantContentRecords() && !_hideIrrelevantRecords( objectName ) ) {
					continue;
				}
				updated = _getContentObjectDao().updateData(
					  filter          = "content_type = :content_type and (hidden is null or hidden = :hidden) and last_scan_process_id = :last_scan_process_id and not exists (select 1 from pobj_tracked_content_object_dependency d where d.content_object = tracked_content_object.id or d.dependent_content_object = tracked_content_object.id)"
					, filterParams    = { content_type=objectName, last_scan_process_id=_getProcessId(), hidden=false }
					, data            = { hidden=true }
					, setDateModified = false
				);
				if ( updated > 0 ) {
					logger.info( "hiding [#updated#] [#objectName#] record(s) without dependencies" );
				}
			}

			updated = _getContentObjectDao().updateData(
				  filter          = { requires_scanning=true, last_scan_process_id=_getProcessId() }
				, data            = { requires_scanning=false }
				, setDateModified = false
			);
			if ( updated > 0 ) {
				logger.info( "Marked [#updated#] scanned content object(s) to not require scanning anymore (processed within this run)." );
			}

			// deal with orphaned content objects
			updated = _getContentObjectDao().updateData(
				  filter          = { requires_scanning=true, orphaned=true }
				, data            = { requires_scanning=false, last_scan_process_id=_getProcessId(), last_scanned=_getProcessTimestamp() }
				, setDateModified = false
			);
			if ( updated > 0 ) {
				logger.info( "Marked [#updated#] orphaned content object(s) to not require scanning anymore." );
			}

			deleted = _getDependencyDao().deleteData(
				  filter       = "content_object in (select id from pobj_tracked_content_object where orphaned = :tracked_content_object.orphaned and last_scan_process_id = :tracked_content_object.last_scan_process_id)"
				, filterParams = { "tracked_content_object.orphaned"=true, "tracked_content_object.last_scan_process_id"=_getProcessId() }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] dependencies of orphaned content objects." );
			}

			_clearCachedContentObjectData();

			logger.info( "Done." );

			return true;
		}
	}

	public void function removeOrphanedContentObjects( any logger ) {
		logger.info( "Now removing all content objects that are flagged as orphaned..." );

		_getDependencyDao().deleteData(
			  filter       = "content_object in (select id from pobj_tracked_content_object where orphaned = :tracked_content_object.orphaned)"
			, filterParams = { "tracked_content_object.orphaned"=true }
		);

		var deleted = _getContentObjectDao().deleteData(
			  filter       = "orphaned = :orphaned and not exists (select 1 from pobj_tracked_content_object_dependency d where d.content_object = tracked_content_object.id or d.dependent_content_object = tracked_content_object.id)"
			, filterParams = { orphaned=true }
		);
		if ( deleted > 0 ) {
			logger.info( "Removed [#deleted#] orphaned content object(s) that have no dependencies anymore" );
		}
		else {
			logger.info( "Nothing to delete." );
		}

		var broken = _getContentObjectDao().selectData(
			  filter          = "orphaned = :orphaned and exists (select 1 from pobj_tracked_content_object_dependency d where d.content_object = tracked_content_object.id or d.dependent_content_object = tracked_content_object.id)"
			, filterParams    = { orphaned=true }
			, recordCountOnly = true
		);
		if ( broken > 0 ) {
			logger.info( "Found [#broken#] orphaned content object(s) that other content objects depend on (Broken dependencies). Those have not been deleted." );
		}

		var validContentTypes = _getTrackingEnabledObjects();

		if ( !isEmpty( validContentTypes ) ) {
			deleted = _getDependencyDao().deleteData(
				  filter       = "content_object.content_type not in (:validContentTypes) or dependent_content_object.content_type not in (:validContentTypes)"
				, filterParams = { validContentTypes={ value=validContentTypes, type="cf_sql_varchar", list=true } }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] dependency record(s) which belong(s) to content objects that are not tracked (anymore)" );
			}
			deleted = _getContentObjectDao().deleteData(
				  filter       = "content_type not in (:validContentTypes)"
				, filterParams = { validContentTypes={ value=validContentTypes, type="cf_sql_varchar", list=true } }
			);
			if ( deleted > 0 ) {
				logger.info( "Removed [#deleted#] content object(s) that is/are not tracked (anymore)" );
			}
		}

		logger.info( "Done." );
	}

	public numeric function getContentObjectId( required string contentType, required string contentId ) {
		var records = _getContentObjectDao().selectData(
			  filter       = { content_type=arguments.contentType, content_id=arguments.contentId }
			, selectFields = [ "id" ]
		);

		for ( var record in records ) {
			return record.id;
		}

		return 0;
	}

	public struct function getContentObject( required string contentType, required string contentId ) {
		var records = _getContentObjectDao().selectData(
			  filter       = { content_type=arguments.contentType, content_id=arguments.contentId }
			, selectFields = [ "id", "label", "depends_on_count", "dependent_by_count" ]
		);

		for ( var record in records ) {
			return record;
		}

		return {};
	}

	public void function createContentObject( required string objectName, required string id ) {
		// the label will be added later during the actual scanning
		_getContentObjectDao().insertData(
			data = {
				  content_type      = arguments.objectName
				, content_id        = arguments.id
				, label             = "tmp-" & arguments.id
				, orphaned          = false
				, hidden            = false
				, requires_scanning = true
			}
		);
	}

	public void function flagContentObjectForScanning( required string objectName, required string id ) {
		_getContentObjectDao().updateData(
			  data   = { requires_scanning=true }
			, filter = { content_type=arguments.objectName, content_id=arguments.id }
		);
	}

	public void function flagContentObjectsDeleted( required string objectName, required array ids ) {
		_getContentObjectDao().updateData(
			  data   = { orphaned=true, requires_scanning=true }
			, filter = { content_type=arguments.objectName, content_id=arguments.ids }
		);
	}

	public string function renderTrackedContentObjectLabel( required string contentType, required string label ) {
		if ( len( arguments.contentType ) && hasCustomLabelRenderer( arguments.contentType ) ) {
			var customLabelRenderer = getCustomLabelRenderer( arguments.contentType );
			return $helpers.renderContent( customLabelRenderer, arguments.label );
		}
		
		return htmlEditFormat( arguments.label );
	}

	public boolean function hasCustomRecordLinkRenderer( required string objectName ) {
		return structKeyExists( _getCustomRecordLinkRenderers(), arguments.objectName );
	}

	public string function getCustomRecordLinkRenderer( required string objectName ) {
		return _getCustomRecordLinkRenderers()[ arguments.objectName ];
	}

	public boolean function hasCustomLabelRenderer( required string objectName ) {
		return structKeyExists( _getCustomLabelRenderers(), arguments.objectName );
	}

	public string function getCustomLabelRenderer( required string objectName ) {
		return _getCustomLabelRenderers()[ arguments.objectName ];
	}

	public string function renderTrackedContentObjectField( required string contentType, required string fieldValue ) {
		// TODO: maybe add support for custom field renderers? (additional annotation on object level)
		return $translateResource( uri="preside-objects.#arguments.contentType#:field.#arguments.fieldValue#.title", defaultValue=arguments.fieldValue );
	}

	public boolean function isEnabled() {
		return _isBooleanSystemSettingEnabled( setting="enabled" );
	}

	public boolean function isTrackingEnabledObject( required string objectName ) {
		return _getTrackingEnabledObjects().contains( arguments.objectName );
	}

	public boolean function showAllOrphanedRecords() {
		return _isBooleanSystemSettingEnabled( setting="show_all_orphaned_records" );
	}

	public boolean function showHiddenRecords() {
		return _isBooleanSystemSettingEnabled( setting="show_hidden_records" );
	}

	public boolean function isSingleRecordScanningEnabled() {
		return _isBooleanSystemSettingEnabled( setting="single_record_scanning" );
	}

	public struct function detectContentObjectByRequestContext( required any rc ) {

		var eventName = trim( arguments.rc.event ?: "" );

		if ( isEmpty( eventName ) ) {
			return {};
		}

		var linkToTrackerEvents = _getLinkToTrackerEventConfig();

		if ( !structKeyExists( linkToTrackerEvents, eventName ) ) {
			return {};
		}

		var linkToTrackerEvent = linkToTrackerEvents[ eventName ];
		var contentType        = linkToTrackerEvent.contentType      ?: "";
		var contentTypeParam   = linkToTrackerEvent.contentTypeParam ?: "";
		var contentIdParam     = linkToTrackerEvent.contentIdParam   ?: "";
		var contentId          = "";

		if ( isEmpty( contentType ) && !isEmpty( contentTypeParam ) ) {
			contentType = arguments.rc[ contentTypeParam ] ?: "";
		}
		if ( !isEmpty( contentIdParam ) ) {
			contentId = arguments.rc[ contentIdParam ] ?: "";
		}
		if ( isEmpty( contentType ) && isEmpty( contentId ) ) {
			return {};
		}

		// TODO: maybe add support for custom detectors? (additional annotation on object level)

		if ( !isTrackingEnabledObject( contentType ) ) {
			return {};
		}

		return getContentObject( contentType, contentId );
	}

// PRIVATE FUNCTIONS
	private void function _indexContentObjects( required string objectName, required array contentIds, any logger ) {

		if ( !_isFullProcessing() && isEmpty( arguments.contentIds ) ) {
			return;
		}

		var idField    = _getPresideObjectService().getIdField( objectName );
		var labelField = _getPresideObjectService().getLabelField( objectName );

		var hasCustomLabelGenerator = _hasCustomLabelGenerator( arguments.objectName );
		var customLabelGenerator    = hasCustomLabelGenerator ? _getCustomLabelGenerator( arguments.objectName ) : "";

		labelField = len( labelField ) ? labelField : idField;

		var selectFields = [ "#idField# as id", "#labelField# as label" ];
		var filter       = !_isFullProcessing() ? { "#idField#"=arguments.contentIds } : {};

		var records = _getPresideObjectService().selectData( objectName=objectName, filter=filter, selectFields=selectFields );

		logger.info( "Now scanning [#records.recordCount#] [#arguments.objectName#] object(s)..." );

		var updated = 0;
		var label   = "";
		var counter = { inserted=0, updated=0 };

		for ( var record in records ) {
			label = record.label;
			if ( hasCustomLabelGenerator ) {
				label = $renderContent( renderer=customLabelGenerator, data=record.id );
			}
			updated = _getContentObjectDao().updateData(
				  data   = {
					  label                = label
					, orphaned             = false
					, requires_scanning    = true
					, last_scan_process_id = _getProcessId()
					, last_scanned         = _getProcessTimestamp()
				}
				, filter = { content_type=arguments.objectName, content_id=record.id }
			);
			if ( !updated ) {
				_getContentObjectDao().insertData(
					data = {
						  content_type         = arguments.objectName
						, content_id           = record.id
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

		logger.info( "Scanning of [#arguments.objectName#] object(s) completed (inserted: #counter.inserted#, updated: #counter.updated#)" );
	}

	private void function _indexContentObjectDependencies( required string objectName, required array contentIds, any logger ) {

		if ( !_isFullProcessing() && isEmpty( arguments.contentIds ) ) {
			return;
		}

		var isForeignKeyScanningEnabled    = _isForeignKeyScanningEnabled();
		var isSoftReferenceScanningEnabled = _isSoftReferenceScanningEnabled();

		logger.info( "Now detecting [#arguments.objectName#] object dependencies (FK Scanning enabled: #isForeignKeyScanningEnabled#, Soft Reference Scanning enabled: #isSoftReferenceScanningEnabled#)..." );

		var props = _getTrackingEnabledObjectProperties( arguments.objectName );

		if ( isEmpty( props ) ) {
			logger.info( "No trackable properties found." );
			return;
		}

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
				var relatedObjectIdField = _getPresideObjectService().getIdField( props[ propName ].relatedTo );
				arrayAppend( selectFields, "GROUP_CONCAT( DISTINCT #propName#.#relatedObjectIdField# ) AS #propName#" );
			}
			else {
				arrayAppend( selectFields, propName );
			}
		}

		var idField = _getPresideObjectService().getIdField( objectName );

		arrayAppend( selectFields, idField );

		var filter                  = !_isFullProcessing() ? { "#idField#"=arguments.contentIds } : {};
		var records                 = _getPresideObjectService().selectData( objectName=arguments.objectName, selectFields=selectFields );
		var propName                = "";
		var propValue               = "";
		var sourceRecordId          = "";
		var relatedContentObjectIds = [];
		var upsertResult			= {};
		var counter                 = { inserted=0, updated=0, deleted=0 };

		for ( var record in records ) {
			if ( !_isTrackedContentObjectId( record.id ) ) {
				continue;
			}
			sourceRecordId = _mapContentObjectId( contentType=arguments.objectName, contentId=record.id );
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
					relatedContentObjectIds = [ propValue ];
					relationTargetObject    = props[ propName ].relatedTo;
					if ( props[ propName ].relationship == "many-to-many" ) {
						relatedContentObjectIds = listToArray( relatedContentObjectIds );
					}
				}
				else {
					// soft references
					relatedContentObjectIds = _findUuids( propValue );
					relationTargetObject    = "";
				}
				upsertResult = _syncDependencies(
					  sourceRecordId             = sourceRecordId
					, dependentContentObjectIds  = relatedContentObjectIds
					, dependentObjectContentType = relationTargetObject
					, fieldName                  = propName
				);
				counter.updated  += upsertResult.updated;
				counter.inserted += upsertResult.inserted;
			}
			counter.deleted  += _getDependencyDao().deleteData(
				  filter       = "content_object = :content_object and (last_scan_process_id is null or last_scan_process_id != :last_scan_process_id)"
				, filterParams = { content_object=sourceRecordId, last_scan_process_id=_getProcessId() }
			);
		}

		logger.info( "Processing of [#arguments.objectName#] content object dependencies completed (inserted: #counter.inserted#, updated: #counter.updated#, deleted: #counter.deleted#)" );
	}

	private struct function _syncDependencies(
		  required string sourceRecordId
		, required array  dependentContentObjectIds
		, required string dependentObjectContentType
		, required string fieldName
	) {
		var result = { inserted=0, updated=0, deleted=0 };
		var targetRecordIds = _mapContentObjectIds( contentIds=dependentContentObjectIds, contentType=dependentObjectContentType );
		if ( isEmpty( targetRecordIds ) ) {
			return result;
		}

		var updated         = 0;
		var isSoftReference = isEmpty( arguments.dependentObjectContentType ); // soft references have no content type, only hard references do (FKs)

		for ( var targetRecordId in targetRecordIds ) {
			updated = _getDependencyDao().updateData(
				  data   = {
					last_scan_process_id = _getProcessId()
				}
				, filter = {
					  content_object           = arguments.sourceRecordId
					, dependent_content_object = targetRecordId
					, content_object_field     = arguments.fieldName
				}
			);
			if ( !updated ) {
				_getDependencyDao().insertData(
					data = {
						  content_object           = arguments.sourceRecordId
						, dependent_content_object = targetRecordId
						, content_object_field     = arguments.fieldName
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

	private struct function _getAllObjectSettingsFromConfig() {
		var settings = _getSettings();
		return settings.trackObjects ?: {};
	}

	private struct function _getObjectSettingsFromConfig( required string objectName ) {
		var settings = _getAllObjectSettingsFromConfig();
		return settings[ arguments.objectName ] ?: {};
	}

	private array function _getTrackingEnabledObjects() {
		return _mergeAnnotatedAndConfiguredBooleanObjectLists( annotation="dependencyTrackerEnabled", setting="enabled" );
	}

	private array function _getHideIrrelevantRecordsObjects() {
		return _mergeAnnotatedAndConfiguredBooleanObjectLists( annotation="dependencyTrackerHideIrrelevantRecords", setting="hideIrrelevantRecords" );
	}

	private boolean function _hideIrrelevantRecords( required string objectName ) {
		return _getHideIrrelevantRecordsObjects().contains( arguments.objectName );
	}

	private struct function _getCustomLabelGenerators() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerLabelGenerator", setting="labelGenerator" );
	}

	private boolean function _hasCustomLabelGenerator( required string objectName ) {
		return structKeyExists( _getCustomLabelGenerators(), arguments.objectName );
	}

	private string function _getCustomLabelGenerator( required string objectName ) {
		return _getCustomLabelGenerators()[ arguments.objectName ];
	}

	private struct function _getCustomLabelRenderers() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerLabelRenderer", setting="labelRenderer" );
	}

	private struct function _getCustomRecordLinkRenderers() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerViewRecordLinkRenderer", setting="viewRecordLinkRenderer" );
	}

	private struct function _getTrackingEnabledObjectProperties( required string objectName ) {
		var args = arguments;

		return _simpleLocalCache( "getTrackingEnabledObjectProperties_" & args.objectName, function() {

			var props                  = _getPresideObjectService().getObjectProperties( args.objectName );
			var enabledProps           = _mergeAnnotatedAndConfiguredBooleanPropertyLists( objectName=args.objectName, annotation="dependencyTrackerEnabled", setting="enabled", expected=true  );
			var disabledProps          = _mergeAnnotatedAndConfiguredBooleanPropertyLists( objectName=args.objectName, annotation="dependencyTrackerEnabled", setting="enabled", expected=false );
			var result                 = {};
			var autoEnableDbTextFields = _autoEnableDbTextFields();

			for ( var propName in props ) {
				var dependencyTrackerEnabled = arrayContainsNoCase( enabledProps, propName ) ? true : "";

				if ( isEmpty( dependencyTrackerEnabled ) && arrayContainsNoCase( disabledProps, propName ) ) {
					continue;
				}

				var relationship   = props[ propName ].relationship ?: "";
				var relatedTo      = props[ propName ].relatedTo    ?: "";
				var dbType         = props[ propName ].dbType       ?: "";
				var isRelationship = len( relationship ) && len( relatedTo ) && relationship != "none" && relatedTo != "none";

				if ( isRelationship && relationship == "one-to-many" ) {
					continue;
				}

				if ( isRelationship && !isTrackingEnabledObject( relatedTo ) ) {
					continue;
				}

				if ( isRelationship && isEmpty( dependencyTrackerEnabled ) ) {
					dependencyTrackerEnabled = true;
				}

				if ( !isRelationship && isEmpty( dependencyTrackerEnabled ) && autoEnableDbTextFields && dbType == "text" ) {
					dependencyTrackerEnabled = true;
				}

				if ( isBoolean( dependencyTrackerEnabled ) && dependencyTrackerEnabled ) {
					result[ propName ] = {
						  relationship   = relationship
						, relatedTo      = relatedTo
						, isRelationship = isRelationship
					};
				}
			}

			return result;
		} );
	}

	private any function _getTrackedContentObjectIds() {
		return _simpleLocalCache( "getTrackedContentObjectIds", function() {

			var records  = _getContentObjectDao().selectData( selectFields=[ "content_id" ], distinct=true );
			var result = createObject( "java", "java.util.HashSet" ).init();

			if ( records.recordCount ) {
				result.addAll( queryColumnData( records, "content_id" ) );
			}

			return result;
		} );
	}

	private struct function _getMappedContentObjectIds() {
		return _simpleLocalCache( "getMappedContentObjectIds", function() {

			var records = _getContentObjectDao().selectData( selectFields=[ "content_id", "content_type", "id" ] );
			var result  = {};

			loop query="records" {
				result[ "#records.content_type#_#records.content_id#" ] = records.id;
			}

			return result;
		} );
	}

	private numeric function _mapContentObjectId( required string contentType, required string contentId ) {

		if ( _isFullProcessing() ) {
			var mappings = _getMappedContentObjectIds();
			return mappings[ arguments.contentType & "_" & arguments.contentId ] ?: 0;
		}

		return getContentObjectId( arguments.contentType, arguments.contentId );
	}

	private array function _mapContentObjectIds( required array contentIds, string contentType="" ) {
		var mappedId = 0;
		var result   = [];
		var type     = "";

		// either a content type is supplied or it's unknown and therefore we need to consider all content types
		var contentTypes = len( arguments.contentType ) ? [ arguments.contentType ] : _getTrackingEnabledObjects();

		for ( var contentId in arguments.contentIds ) {
			
			if ( !_isTrackedContentObjectId( contentId ) ) {
				continue;
			}

			for ( type in contentTypes ) {
				mappedId = _mapContentObjectId( contentType=type, contentId=contentId );
				if ( mappedId > 0 ) {
					arrayAppend( result, mappedId );
				}
			}
		}

		return result;
	}

	private boolean function _isTrackedContentObjectId( required any contentId ) {
		if ( _isFullProcessing() ) {
			return _getTrackedContentObjectIds().contains( arguments.contentId );
		}
		return _getContentObjectDao().dataExists( filter={ content_id=arguments.contentId } );
	}

	private void function _cacheContentObjectData() {
		_clearCachedContentObjectData();
		_getTrackedContentObjectIds();
		_getMappedContentObjectIds();
	}

	private void function _clearCachedContentObjectData() {
		structDelete( _getLocalCache(), "getTrackedContentObjectIds" );
		structDelete( _getLocalCache(), "getMappedContentObjectIds" );
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

	private struct function _mergeAnnotatedAndConfiguredObjectMaps( required string annotation, required string setting ) {
		var args = arguments;
		return _simpleLocalCache( "_mergeAnnotatedAndConfiguredObjectMaps_#args.annotation#_#args.setting#", function() {
			var result = {};

			var objectNames   = _getPresideObjectService().listObjects();
			var annotatedMap  = _getAnnotatedObjectMap( annotation=args.annotation );
			var configuredMap = _getConfiguredObjectMap( setting=args.setting );

			for ( var objectName in objectNames ) {
				if ( structKeyExists( annotatedMap, objectName ) ) {
					if ( len( annotatedMap[ objectName ] ) ) {
						result[ objectName ] = annotatedMap[ objectName ];
					}
					continue;
				}
				if ( structKeyExists( configuredMap, objectName ) && len( configuredMap[ objectName ] ) ) {
					result[ objectName ] = configuredMap[ objectName ];
				}
			}

			return result;
		} );
	}

	private struct function _getAnnotatedObjectMap( required string annotation ) {
		var args = arguments;
		return _simpleLocalCache( args.annotation, function() {
			var objects         = _getPresideObjectService().listObjects();
			var annotationValue = ""
			var result          = {};

			for ( var objectName in objects ) {
				annotationValue = _getPresideObjectService().getObjectAttribute( objectName, args.annotation, "---INVALID---" );
				if ( annotationValue != "---INVALID---" ) {
					result[ objectName ] = annotationValue;
				}
			}

			return result;
		} );
	}

	private struct function _getConfiguredObjectMap( required string setting ) {
		var args = arguments;
		return _simpleLocalCache( args.setting, function() {
			var objects = _getAllObjectSettingsFromConfig();
			var result  = {};

			for ( var objectName in objects ) {
				if ( structKeyExists( objects[ objectName ], args.setting ) ) {
					result[ objectName ] = trim( objects[ objectName ][ args.setting ] );
				}
			}

			return result;
		} );
	}

	private array function _mergeAnnotatedAndConfiguredBooleanObjectLists( required string annotation, required string setting ) {
		var args = arguments;
		return _simpleLocalCache( "_mergeAnnotatedAndConfiguredBooleanObjectLists_#args.annotation#_#args.setting#", function() {
			var result = [];

			var objectNames            = _getPresideObjectService().listObjects();
			var annotatedTrueObjects   = _getAnnotatedBooleanObjectList( annotation=args.annotation, expected=true  );
			var annotatedFalseObjects  = _getAnnotatedBooleanObjectList( annotation=args.annotation, expected=false );
			var configuredTrueObjects  = _getConfiguredBooleanObjectList( setting=args.setting, expected=true  );
			var configuredFalseObjects = _getConfiguredBooleanObjectList( setting=args.setting, expected=false );

			for ( var objectName in objectNames ) {
				if ( arrayFindNoCase( annotatedFalseObjects, objectName ) ) {
					continue;
				}
				if ( arrayFindNoCase( annotatedTrueObjects, objectName ) ) {
					arrayAppend( result, objectName );
					continue;
				}
				if ( arrayFindNoCase( configuredFalseObjects, objectName ) ) {
					continue;
				}
				if ( arrayFindNoCase( configuredTrueObjects, objectName ) ) {
					arrayAppend( result, objectName );
				}
			}

			return result;
		} );
	}

	private array function _getAnnotatedBooleanObjectList( required string annotation, boolean expected=true ) {
		var args = arguments;
		return _simpleLocalCache( "_getAnnotatedBooleanObjectList_#args.annotation#_#args.expected#", function() {
			var objects = _getPresideObjectService().listObjects();
			var result  = [];
			var value   = "";

			for ( var objectName in objects ) {
				value = _getPresideObjectService().getObjectAttribute( objectName, args.annotation, "" );
				if ( !isBoolean( value ) ) {
					continue;
				}
				if ( ( args.expected && value ) || ( !args.expected && !value ) ) {
					arrayAppend( result, objectName );
				}
			}

			return result;
		} );
	}

	private array function _getConfiguredBooleanObjectList( required string setting, boolean expected=true ) {
		var args = arguments;
		return _simpleLocalCache( "_getConfiguredBooleanObjectList_#args.setting#_#args.expected#", function() {
			var objects = _getAllObjectSettingsFromConfig();
			var result  = [];
			var value   = "";

			for ( var objectName in objects ) {
				value = objects[ objectName ][ args.setting ] ?: "";
				if ( !isBoolean( value ) ) {
					continue;
				}
				if ( ( args.expected && value ) || ( !args.expected && !value ) ) {
					arrayAppend( result, objectName );
				}
			}

			return result;
		} );
	}

	private array function _mergeAnnotatedAndConfiguredBooleanPropertyLists( required string objectName, required string annotation, required string setting, boolean expected=true ) {
		var args = arguments;
		return _simpleLocalCache( "_mergeAnnotatedAndConfiguredBooleanPropertyLists_#args.objectName#_#args.annotation#_#args.setting#_#args.expected#", function() {
			var result = [];

			var props                     = _getPresideObjectService().getObjectProperties( args.objectName );
			var annotatedTrueProperties   = _getAnnotatedBooleanPropertyList(  objectName=args.objectName, annotation=args.annotation, expected=true  );
			var annotatedFalseProperties  = _getAnnotatedBooleanPropertyList(  objectName=args.objectName, annotation=args.annotation, expected=false );
			var configuredTrueProperties  = _getConfiguredBooleanPropertyList( objectName=args.objectName, setting=args.setting      , expected=true  );
			var configuredFalseProperties = _getConfiguredBooleanPropertyList( objectName=args.objectName, setting=args.setting      , expected=false );

			for ( var propName in props ) {
				if ( args.expected ) {
					if ( arrayFindNoCase( annotatedTrueProperties, propName ) ) {
						arrayAppend( result, propName );
						continue;
					}
					if ( arrayFindNoCase( annotatedFalseProperties, propName ) ) {
						continue;
					}
					if ( arrayFindNoCase( configuredTrueProperties, propName ) ) {
						arrayAppend( result, propName );
					}
				}
				else {
					if ( arrayFindNoCase( annotatedFalseProperties, propName ) ) {
						arrayAppend( result, propName );
						continue;
					}
					if ( arrayFindNoCase( annotatedTrueProperties, propName ) ) {
						continue;
					}
					if ( arrayFindNoCase( configuredFalseProperties, propName ) ) {
						arrayAppend( result, propName );
					}
				}
			}

			return result;
		} );
	}

	private array function _getAnnotatedBooleanPropertyList( required string objectName, required string annotation, boolean expected=true ) {
		var args = arguments;
		return _simpleLocalCache( "_getAnnotatedBooleanPropertyList_#args.objectName#_#args.annotation#_#args.expected#", function() {
			var props  = _getPresideObjectService().getObjectProperties( args.objectName );
			var result = [];
			var value  = "";

			for ( var propName in props ) {
				value = props[ propName ][ args.annotation ] ?: "";
				if ( !isBoolean( value ) ) {
					continue;
				}
				if ( ( args.expected && value ) || ( !args.expected && !value ) ) {
					arrayAppend( result, propName );
				}
			}

			return result;
		} );
	}

	private array function _getConfiguredBooleanPropertyList( required string objectName, required string setting, boolean expected=true ) {
		var args = arguments;
		return _simpleLocalCache( "_getConfiguredBooleanPropertyList_#args.objectName#_#args.setting#_#args.expected#", function() {
			var config = _getObjectSettingsFromConfig( args.objectName );

			if ( !structKeyExists( config, "properties" ) || !isStruct( config.properties ) || isEmpty( config.properties ) ) {
				return [];
			}

			var result = [];
			var value  = "";

			for ( var propName in config.properties ) {
				value = config.properties[ propName ][ args.setting ] ?: "";
				if ( !isBoolean( value ) ) {
					continue;
				}
				if ( ( args.expected && value ) || ( !args.expected && !value ) ) {
					arrayAppend( result, propName );
				}
			}

			return result;
		} );
	}

	private struct function _getScanningRequiredContentObjectMap() {
		var records = _getContentObjectDao().selectData(
			  filter       = { requires_scanning=true }
			, selectFields = [ "content_type", "content_id" ]
		);

		var result = {};

		loop query="records" {
			if ( !structKeyExists( result, records.content_type ) ) {
				result[ records.content_type ] = [];
			}
			arrayAppend( result[ records.content_type ], records.content_id );
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

	private boolean function _isForeignKeyScanningEnabled() {
		return _isBooleanSystemSettingEnabled( setting="fk_scanning_enabled" );
	}

	private boolean function _isSoftReferenceScanningEnabled() {
		return _isBooleanSystemSettingEnabled( setting="soft_reference_scanning_enabled" );
	}

	private boolean function _hideAllIrrelevantContentRecords() {
		return _isBooleanSystemSettingEnabled( setting="hide_all_irrelevant_records" );
	}

	private boolean function _isBooleanSystemSettingEnabled( required string setting ) {
		var setting = $getPresideSetting( "content-dependency-tracker", arguments.setting );

		return IsBoolean( setting ) && setting;
	}

	private boolean function _isFullProcessing() {
		return _getFullProcessing();
	}

	private struct function _getLinkToTrackerEventConfig() {
		var settings = _getSettings();
		return settings.linkToTrackerEvents ?: {};
	}

	private boolean function _autoEnableDbTextFields() {
		var settings = _getSettings();
		return isBoolean( settings.autoEnableDbTextFields ?: "" ) && settings.autoEnableDbTextFields;
	}

// GETTERS AND SETTERS
	private any function _getPresideObjectService() {
		return _presideObjectService;
	}
	private void function _setPresideObjectService( required any presideObjectService ) {
		_presideObjectService = arguments.presideObjectService;
	}

	private any function _getContentObjectDao() {
		return _contentObjectDao;
	}
	private void function _setContentObjectDao( required any contentObjectDao ) {
		_contentObjectDao = arguments.contentObjectDao;
	}

	private any function _getDependencyDao() {
		return _dependencyDao;
	}
	private void function _setDependencyDao( required any dependencyDao ) {
		_dependencyDao = arguments.dependencyDao;
	}

	private any function _getSettings() {
		return _settings;
	}
	private void function _setSettings( required any settings ) {
		_settings = arguments.settings;
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