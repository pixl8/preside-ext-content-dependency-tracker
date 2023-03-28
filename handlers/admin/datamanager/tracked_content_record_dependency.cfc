component {

	property name="configService" inject="contentDependencyTrackerConfigurationService";

	private string function getAdditionalQueryStringForBuildAjaxListingLink( event, rc, prc, args={} ) {

		var objectName = prc.objectName ?: "";
		var recordId   = prc.recordId   ?: "";

		return ( objectName == "tracked_content_record" ) && len( recordId ) ? "tracked_content_record=#recordId#" : "";
	}

	private void function preFetchRecordsForGridListing( event, rc, prc, args={} ) {
		
		var recordId = len( rc.tracked_content_record ?: "" ) ? rc.tracked_content_record : "";

		args.gridFields   = args.gridFields   ?: [];
		args.extraFilters = args.extraFilters ?: [];

		if ( len( recordId ) ) {
			// TODO: this is a workaround to rely on the presence of a specific grid field. It would be better to use a possibility to pass in an actual parameter to use
			if ( arrayContainsNoCase( args.gridFields, "dependent_content_record" ) ) {
				args.extraFilters.append( { filter={ content_record=recordId } } );
			}
			else {
				args.extraFilters.append( { filter={ dependent_content_record=recordId } } );
			}
		}
	}

	private void function postFetchRecordsForGridListing( event, rc, prc, args={} ) {
		var records = args.records ?: QueryNew( "" );
		var columns = listToArray( records.columnList );

		var contentRecordObjectNameColumExists         = arrayFindNoCase( columns, "content_record_object_name" ) ? true : false;
		var convertContentRecordField                  = arrayFindNoCase( columns, "content_record"           ) && contentRecordObjectNameColumExists ? true : false;
		var convertDependentContentRecordField         = arrayFindNoCase( columns, "dependent_content_record" ) && arrayFindNoCase( columns, "dependent_content_record_object_name" ) ? true : false;
		var convertObjectFieldField                    = arrayFindNoCase( columns, "content_record_field"     ) && contentRecordObjectNameColumExists ? true : false;
		var convertContentRecordOrphanedField          = arrayFindNoCase( columns, "content_record_orphaned"           ) ? true : false;
		var convertDependentContentRecordOrphanedField = arrayFindNoCase( columns, "dependent_content_record_orphaned" ) ? true : false;
		var convertIsSoftReferenceField                = arrayFindNoCase( columns, "soft_or_fk"                        ) ? true : false;

		var contentRecordOrphanedBooleanBadgeTrue           = "";
		var contentRecordOrphanedBooleanBadgeFalse          = "";
		var dependentContentRecordOrphanedBooleanBadgeTrue  = "";
		var dependentContentRecordOrphanedBooleanBadgeFalse = "";
		var isSoftReferenceBooleanBadgeTrue                 = "";
		var isSoftReferenceBooleanBadgeFalse                = "";

		if ( convertContentRecordOrphanedField ) {
			contentRecordOrphanedBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_record_dependency", propertyName="content_record_orphaned" }, context=[ "admin" ] );
			contentRecordOrphanedBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_record_dependency", propertyName="content_record_orphaned" }, context=[ "admin" ] );
		}

		if ( convertDependentContentRecordOrphanedField ) {
			dependentContentRecordOrphanedBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_record_dependency", propertyName="dependent_content_record_orphaned" }, context=[ "admin" ] );
			dependentContentRecordOrphanedBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_record_dependency", propertyName="dependent_content_record_orphaned" }, context=[ "admin" ] );
		}

		if ( convertIsSoftReferenceField ) {
			isSoftReferenceBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_record_dependency", propertyName="soft_or_fk" }, context=[ "admin" ] );
			isSoftReferenceBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_record_dependency", propertyName="soft_or_fk" }, context=[ "admin" ] );
		}

		loop query="records" {
			if ( convertContentRecordField ) {
				querySetCell( records, "content_record", configService.renderTrackedContentRecordLabel( objectName=records.content_record_object_name, label=records.content_record ), currentRow );
			}
			if ( convertDependentContentRecordField ) {
				querySetCell( records, "dependent_content_record", configService.renderTrackedContentRecordLabel( objectName=records.dependent_content_record_object_name, label=records.dependent_content_record ), currentRow );
			}
			if ( convertObjectFieldField ) {
				querySetCell( records, "content_record_field", configService.renderTrackedContentRecordField( objectName=records.content_record_object_name, fieldValue=records.content_record_field ), currentRow );
			}
			if ( convertContentRecordOrphanedField ) {
				querySetCell( records, "content_record_orphaned", ( isBoolean( records.content_record_orphaned ) && records.content_record_orphaned ) ? contentRecordOrphanedBooleanBadgeTrue : contentRecordOrphanedBooleanBadgeFalse, currentRow );
			}
			if ( convertDependentContentRecordOrphanedField ) {
				querySetCell( records, "dependent_content_record_orphaned", ( isBoolean( records.dependent_content_record_orphaned ) && records.dependent_content_record_orphaned ) ? dependentContentRecordOrphanedBooleanBadgeTrue : dependentContentRecordOrphanedBooleanBadgeFalse, currentRow );
			}
			if ( convertIsSoftReferenceField ) {
				querySetCell( records, "soft_or_fk", ( isBoolean( records.soft_or_fk ) && records.soft_or_fk ) ? isSoftReferenceBooleanBadgeTrue : isSoftReferenceBooleanBadgeFalse, currentRow );
			}
		}
	}

	private array function getRecordActionsForGridListing( event, rc, prc, args={} ) {
		var objectName               = args.objectName                    ?: "";
		var record                   = args.record                        ?: {};
		var recordId                 = record.id                          ?: "";
		var contentRecordId          = record.content_record_id           ?: "";
		var dependentContentRecordId = record.dependent_content_record_id ?: "";

		if ( len( contentRecordId ) ) {
			objectName = "tracked_content_record";
			recordId   = contentRecordId;
		}
		else if ( len( dependentContentRecordId ) ) {
			objectName = "tracked_content_record";
			recordId   = dependentContentRecordId;
		}

		return [ {
			  link = event.buildAdminLink( objectName=objectName, recordid=recordId )
			, icon = "fa-eye"
		} ];
	}
}