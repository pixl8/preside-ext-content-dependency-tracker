/**
 * @versioned                    false
 * @dataManagerEnabled           true
 * @nolabel                      true
 * @datamanagerAllowedOperations read
 */
component {
	property name="id" type="numeric" dbtype="bigint" required=true generator="increment";

	property name="content_record"           relationship="many-to-one" relatedTo="tracked_content_record" required=true indexes="dependentRecordsAndField|1";
	property name="dependent_content_record" relationship="many-to-one" relatedTo="tracked_content_record" required=true indexes="dependentRecordsAndField|2";

	property name="content_record_field" type="string"  dbtype="varchar" maxlength=100 required=true indexes="dependentRecordsAndField|3";
	property name="is_soft_reference"    type="boolean" dbtype="bit"                   required=true;
	property name="last_scan_process_id" type="string"  dbtype="varchar" maxlength=35  required=false autofilter=false indexes="lastScanProcessId";

	property name="content_record_object_name" type="string" formula="${prefix}content_record.object_name" renderer="objectName";
	property name="content_record_id"          type="string" formula="${prefix}content_record.id";
	property name="content_record_orphaned"    type="string" formula="${prefix}content_record.orphaned" adminRenderer="booleanBadge";

	property name="dependent_content_record_object_name" type="string" formula="${prefix}dependent_content_record.object_name" renderer="objectName";
	property name="dependent_content_record_id"          type="string" formula="${prefix}dependent_content_record.id";
	property name="dependent_content_record_orphaned"    type="string" formula="${prefix}dependent_content_record.orphaned" adminRenderer="booleanBadge";

	property name="soft_or_fk" type="string" formula="${prefix}is_soft_reference" adminRenderer="booleanBadge";
}