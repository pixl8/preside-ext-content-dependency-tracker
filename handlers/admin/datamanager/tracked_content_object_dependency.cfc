component {

	property name="contentDependencyTrackerService" inject="contentDependencyTrackerService";

	private string function getAdditionalQueryStringForBuildAjaxListingLink( event, rc, prc, args={} ) {

		var objectName = prc.objectName ?: "";
		var recordId   = prc.recordId   ?: "";

		return ( objectName == "tracked_content_object" ) && len( recordId ) ? "tracked_content_object=#recordId#" : "";
	}

	private void function preFetchRecordsForGridListing( event, rc, prc, args={} ) {
		
		var recordId = len( rc.tracked_content_object ?: "" ) ? rc.tracked_content_object : "";

		args.gridFields   = args.gridFields   ?: [];
		args.extraFilters = args.extraFilters ?: [];

		if ( len( recordId ) ) {
			// TODO: this is a workaround to rely on the presence of a specific grid field. It would be better to use a possibility to pass in an actual parameter to use
			if ( arrayContainsNoCase( args.gridFields, "dependent_content_object" ) ) {
				args.extraFilters.append( { filter={ content_object=recordId } } );
			}
			else {
				args.extraFilters.append( { filter={ dependent_content_object=recordId } } );
			}
		}
	}

	private void function postFetchRecordsForGridListing( event, rc, prc, args={} ) {
		var records = args.records ?: QueryNew( "" );
		var columns = listToArray( records.columnList );

		var convertContentObjectField                  = arrayFindNoCase( columns, "content_object"           ) && arrayFindNoCase( columns, "content_object_type"           ) ? true : false;
		var convertDependentContentObjectField         = arrayFindNoCase( columns, "dependent_content_object" ) && arrayFindNoCase( columns, "dependent_content_object_type" ) ? true : false;
		var convertObjectFieldField                    = arrayFindNoCase( columns, "content_object_field"     ) && arrayFindNoCase( columns, "content_object_type"           ) ? true : false;
		var convertContentObjectOrphanedField          = arrayFindNoCase( columns, "content_object_orphaned"           ) ? true : false;
		var convertDependentContentObjectOrphanedField = arrayFindNoCase( columns, "dependent_content_object_orphaned" ) ? true : false;
		var convertIsSoftReferenceField                = arrayFindNoCase( columns, "soft_or_fk"                        ) ? true : false;

		var contentObjectOrphanedBooleanBadgeTrue           = "";
		var contentObjectOrphanedBooleanBadgeFalse          = "";
		var dependentContentObjectOrphanedBooleanBadgeTrue  = "";
		var dependentContentObjectOrphanedBooleanBadgeFalse = "";
		var isSoftReferenceBooleanBadgeTrue                 = "";
		var isSoftReferenceBooleanBadgeFalse                = "";

		if ( convertContentObjectOrphanedField ) {
			contentObjectOrphanedBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_object_dependency", propertyName="content_object_orphaned" }, context=[ "admin" ] );
			contentObjectOrphanedBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_object_dependency", propertyName="content_object_orphaned" }, context=[ "admin" ] );
		}

		if ( convertDependentContentObjectOrphanedField ) {
			dependentContentObjectOrphanedBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_object_dependency", propertyName="dependent_content_object_orphaned" }, context=[ "admin" ] );
			dependentContentObjectOrphanedBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_object_dependency", propertyName="dependent_content_object_orphaned" }, context=[ "admin" ] );
		}

		if ( convertIsSoftReferenceField ) {
			isSoftReferenceBooleanBadgeTrue  = renderContent( renderer="booleanBadge", data={ data=true , objectName="tracked_content_object_dependency", propertyName="soft_or_fk" }, context=[ "admin" ] );
			isSoftReferenceBooleanBadgeFalse = renderContent( renderer="booleanBadge", data={ data=false, objectName="tracked_content_object_dependency", propertyName="soft_or_fk" }, context=[ "admin" ] );
		}

		loop query="records" {
			if ( convertContentObjectField ) {
				querySetCell( records, "content_object", contentDependencyTrackerService.renderTrackedContentObjectLabel( contentType=records.content_object_type, label=records.content_object ), currentRow );
			}
			if ( convertDependentContentObjectField ) {
				querySetCell( records, "dependent_content_object", contentDependencyTrackerService.renderTrackedContentObjectLabel( contentType=records.dependent_content_object_type, label=records.dependent_content_object ), currentRow );
			}
			if ( convertObjectFieldField ) {
				querySetCell( records, "content_object_field", contentDependencyTrackerService.renderTrackedContentObjectField( contentType=records.content_object_type, fieldValue=records.content_object_field ), currentRow );
			}
			if ( convertContentObjectOrphanedField ) {
				querySetCell( records, "content_object_orphaned", ( isBoolean( records.content_object_orphaned ) && records.content_object_orphaned ) ? contentObjectOrphanedBooleanBadgeTrue : contentObjectOrphanedBooleanBadgeFalse, currentRow );
			}
			if ( convertDependentContentObjectOrphanedField ) {
				querySetCell( records, "dependent_content_object_orphaned", ( isBoolean( records.dependent_content_object_orphaned ) && records.dependent_content_object_orphaned ) ? dependentContentObjectOrphanedBooleanBadgeTrue : dependentContentObjectOrphanedBooleanBadgeFalse, currentRow );
			}
			if ( convertIsSoftReferenceField ) {
				querySetCell( records, "soft_or_fk", ( isBoolean( records.soft_or_fk ) && records.soft_or_fk ) ? isSoftReferenceBooleanBadgeTrue : isSoftReferenceBooleanBadgeFalse, currentRow );
			}
		}
	}

	private array function getRecordActionsForGridListing( event, rc, prc, args={} ) {
		var objectName                     = args.objectName                           ?: "";
		var record                         = args.record                               ?: {};
		var recordId                       = record.id                                 ?: "";
		var contentObjectRecordId          = record.content_object_record_id           ?: "";
		var dependentContentObjectRecordId = record.dependent_content_object_record_id ?: "";

		if ( len( contentObjectRecordId ) ) {
			objectName = "tracked_content_object";
			recordId   = contentObjectRecordId;
		}
		else if ( len( dependentContentObjectRecordId ) ) {
			objectName = "tracked_content_object";
			recordId   = dependentContentObjectRecordId;
		}

		return [ {
			  link = event.buildAdminLink( objectName=objectName, recordid=recordId )
			, icon = "fa-eye"
		} ];
	}
}