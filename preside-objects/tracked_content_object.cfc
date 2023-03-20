/**
 * @versioned                    false
 * @dataManagerEnabled           true
 * @dataManagerGridFields        content_type,label,depends_on_count,dependent_by_count,datecreated,datemodified
 * @datamanagerHiddenGridFields  content_id,orphaned
 * @datamanagerAllowedOperations read
 * @labelRenderer                tracked_content_object
 */
component {
	property name="label" renderer="trackedContentObjectLabelRenderer";
	property name="id"                   type="numeric" dbtype="bigint"                  required=true generator="increment";
	property name="content_type"         type="string"  dbtype="varchar" maxlength=50    required=true renderer="objectName" uniqueIndexes="contentTypeAndId";
	property name="content_id"           type="string"  dbtype="varchar" maxlength=35    required=true                       uniqueIndexes="contentTypeAndId";
	property name="orphaned"             type="boolean" dbtype="bit"     default="false" required=true                       indexes="orphaned";
	property name="hidden"               type="boolean" dbtype="bit"     default="false" required=true                       indexes="hidden";
	property name="requires_scanning"    type="boolean" dbtype="bit"     default="false" required=true                       indexes="requires_scanning";
	property name="last_scan_process_id" type="string"  dbtype="varchar" maxlength=35    required=false autofilter=false     indexes="lastScanProcessId";
	property name="last_scanned"         type="date"    dbtype="datetime"                required=false;

	property name="depends_on"   relationship="one-to-many" relatedTo="tracked_content_object_dependency" relationshipKey="content_object";
	property name="dependent_by" relationship="one-to-many" relatedTo="tracked_content_object_dependency" relationshipKey="dependent_content_object";

	property name="depends_on_count"   formula="count( distinct ${prefix}depends_on.id )"   type="numeric" adminRenderer="none";
	property name="dependent_by_count" formula="count( distinct ${prefix}dependent_by.id )" type="numeric" adminRenderer="none";
}