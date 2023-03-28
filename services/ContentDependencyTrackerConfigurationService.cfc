/**
* @singleton      true
* @presideService true
*/
component {

// CONSTRUCTOR
	/**
     * @settings.inject coldbox:setting:contentDependencyTracker
     */
	public any function init( required any settings ) {

		_setSettings( arguments.settings );

		_setLocalCache( {} );

		return this;
	}

// PUBLIC FUNCTIONS
	public string function renderTrackedContentRecordLabel( required string objectName, required string label ) {
		if ( len( arguments.objectName ) && hasCustomLabelRenderer( arguments.objectName ) ) {
			var customLabelRenderer = getCustomLabelRenderer( arguments.objectName );
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

	public string function renderTrackedContentRecordField( required string objectName, required string fieldValue ) {
		// TODO: maybe add support for custom field renderers? (additional annotation on object level)
		return $translateResource( uri="preside-objects.#arguments.objectName#:field.#arguments.fieldValue#.title", defaultValue=arguments.fieldValue );
	}

	public boolean function isEnabled() {
		return _isBooleanSystemSettingEnabled( setting="enabled" );
	}

	public array function getTrackingEnabledObjects() {
		return _mergeAnnotatedAndConfiguredBooleanObjectLists( annotation="dependencyTrackerEnabled", setting="enabled" );
	}

	public boolean function isTrackingEnabledObject( required string objectName ) {
		return ArrayContainsNoCase( getTrackingEnabledObjects(), arguments.objectName );
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

	public boolean function hideIrrelevantRecords( required string objectName ) {
		return ArrayContainsNoCase( _getHideIrrelevantRecordsObjects(), arguments.objectName );
	}

	public boolean function hasCustomLabelGenerator( required string objectName ) {
		return StructKeyExists( _getCustomLabelGenerators(), arguments.objectName );
	}

	public string function getCustomLabelGenerator( required string objectName ) {
		return _getCustomLabelGenerators()[ arguments.objectName ];
	}

	public struct function getTrackingEnabledObjectProperties( required string objectName ) {
		var args = arguments;

		return _simpleLocalCache( "getTrackingEnabledObjectProperties_" & args.objectName, function() {

			var props                  = $getPresideObjectService().getObjectProperties( args.objectName );
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

	public boolean function isForeignKeyScanningEnabled() {
		return _isBooleanSystemSettingEnabled( setting="fk_scanning_enabled" );
	}

	public boolean function isSoftReferenceScanningEnabled() {
		return _isBooleanSystemSettingEnabled( setting="soft_reference_scanning_enabled" );
	}

	public boolean function hideAllIrrelevantContentRecords() {
		return _isBooleanSystemSettingEnabled( setting="hide_all_irrelevant_records" );
	}

	public struct function getLinkToTrackerEventConfig() {
		var settings = _getSettings();
		return settings.linkToTrackerEvents ?: {};
	}

// PRIVATE FUNCTIONS
	private struct function _getAllObjectSettingsFromConfig() {
		var settings = _getSettings();
		return settings.trackObjects ?: {};
	}

	private struct function _getObjectSettingsFromConfig( required string objectName ) {
		var settings = _getAllObjectSettingsFromConfig();
		return settings[ arguments.objectName ] ?: {};
	}

	private array function _getHideIrrelevantRecordsObjects() {
		return _mergeAnnotatedAndConfiguredBooleanObjectLists( annotation="dependencyTrackerHideIrrelevantRecords", setting="hideIrrelevantRecords" );
	}

	private struct function _getCustomLabelGenerators() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerLabelGenerator", setting="labelGenerator" );
	}

	private struct function _getCustomLabelRenderers() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerLabelRenderer", setting="labelRenderer" );
	}

	private struct function _getCustomRecordLinkRenderers() {
		return _mergeAnnotatedAndConfiguredObjectMaps( annotation="dependencyTrackerViewRecordLinkRenderer", setting="viewRecordLinkRenderer" );
	}

	private struct function _mergeAnnotatedAndConfiguredObjectMaps( required string annotation, required string setting ) {
		var args = arguments;
		return _simpleLocalCache( "_mergeAnnotatedAndConfiguredObjectMaps_#args.annotation#_#args.setting#", function() {
			var result = {};

			var objectNames   = $getPresideObjectService().listObjects();
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
			var objects         = $getPresideObjectService().listObjects();
			var annotationValue = ""
			var result          = {};

			for ( var objectName in objects ) {
				annotationValue = $getPresideObjectService().getObjectAttribute( objectName, args.annotation, "---INVALID---" );
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

			var objectNames            = $getPresideObjectService().listObjects();
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
			var objects = $getPresideObjectService().listObjects();
			var result  = [];
			var value   = "";

			for ( var objectName in objects ) {
				value = $getPresideObjectService().getObjectAttribute( objectName, args.annotation, "" );
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

			var props                     = $getPresideObjectService().getObjectProperties( args.objectName );
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
			var props  = $getPresideObjectService().getObjectProperties( args.objectName );
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

	private boolean function _autoEnableDbTextFields() {
		var settings = _getSettings();
		return isBoolean( settings.autoEnableDbTextFields ?: "" ) && settings.autoEnableDbTextFields;
	}

	private boolean function _isBooleanSystemSettingEnabled( required string setting ) {
		var setting = $getPresideSetting( "content-dependency-tracker", arguments.setting );

		return IsBoolean( setting ) && setting;
	}

	private any function _simpleLocalCache( required string cacheKey, required any generator ) {
		var cache = _getLocalCache();

		if ( !cache.keyExists( cacheKey ) ) {
			cache[ cacheKey ] = generator();
		}

		return cache[ cacheKey ] ?: NullValue();
	}

// GETTERS AND SETTERS
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
}