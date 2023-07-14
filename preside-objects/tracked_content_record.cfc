/**
 * @versioned                    false
 * @dataManagerEnabled           true
 * @dataManagerGridFields        object_name,label,depends_on_count,dependent_by_count,datecreated,datemodified
 * @datamanagerHiddenGridFields  record_id,orphaned
 * @datamanagerAllowedOperations navigate,read
 * @labelRenderer                tracked_content_record
 */
component {
	property name="label" renderer="trackedContentRecordLabelRenderer";

	property name="id"                   type="numeric" dbtype="bigint"                  required=true generator="increment";
	property name="object_name"          type="string"  dbtype="varchar" maxlength=50    required=true renderer="objectName" uniqueIndexes="objectNameAndRecordId|1" enum="dependencyTrackerObjectNames";
	property name="record_id"            type="string"  dbtype="varchar" maxlength=35    required=true                       uniqueIndexes="objectNameAndRecordId|2";
	property name="orphaned"             type="boolean" dbtype="bit"     default="false" required=true                       indexes="orphaned";
	property name="hidden"               type="boolean" dbtype="bit"     default="false" required=true                       indexes="hidden";
	property name="requires_scanning"    type="boolean" dbtype="bit"     default="false" required=true                       indexes="requires_scanning";
	property name="last_scan_process_id" type="string"  dbtype="varchar" maxlength=35    required=false autofilter=false     indexes="lastScanProcessId";
	property name="last_scanned"         type="date"    dbtype="datetime"                required=false;

	property name="depends_on"   relationship="one-to-many" relatedTo="tracked_content_record_dependency" relationshipKey="content_record";
	property name="dependent_by" relationship="one-to-many" relatedTo="tracked_content_record_dependency" relationshipKey="dependent_content_record";

	property name="depends_on_count"   formula="count( distinct ${prefix}depends_on.id )"   type="numeric" adminRenderer="none";
	property name="dependent_by_count" formula="count( distinct ${prefix}dependent_by.id )" type="numeric" adminRenderer="none";
}