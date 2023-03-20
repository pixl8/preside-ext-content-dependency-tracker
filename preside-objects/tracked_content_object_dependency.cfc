/**
 * @versioned                    false
 * @dataManagerEnabled           true
 * @nolabel                      true
 * @datamanagerAllowedOperations read
 */
component {
	property name="id" type="numeric" dbtype="bigint" required=true generator="increment";

	property name="content_object"           relationship="many-to-one" relatedTo="tracked_content_object" required=true indexes="dependentObjectsAndField";
	property name="dependent_content_object" relationship="many-to-one" relatedTo="tracked_content_object" required=true indexes="dependentObjectsAndField";

	property name="content_object_field" type="string"  dbtype="varchar" maxlength=100 required=true indexes="dependentObjectsAndField";
	property name="is_soft_reference"    type="boolean" dbtype="bit"                   required=true;
	property name="last_scan_process_id" type="string"  dbtype="varchar" maxlength=35  required=false autofilter=false indexes="lastScanProcessId";

	property name="content_object_type"      type="string" formula="${prefix}content_object.content_type" renderer="objectName";
	property name="content_object_id"        type="string" formula="${prefix}content_object.content_id";
	property name="content_object_record_id" type="string" formula="${prefix}content_object.id";
	property name="content_object_orphaned"  type="string" formula="${prefix}content_object.orphaned" adminRenderer="booleanBadge";

	property name="dependent_content_object_type"      type="string" formula="${prefix}dependent_content_object.content_type" renderer="objectName";
	property name="dependent_content_object_id"        type="string" formula="${prefix}dependent_content_object.content_id";
	property name="dependent_content_object_record_id" type="string" formula="${prefix}dependent_content_object.id";
	property name="dependent_content_object_orphaned"  type="string" formula="${prefix}dependent_content_object.orphaned" adminRenderer="booleanBadge";

	property name="soft_or_fk" type="string" formula="${prefix}is_soft_reference" adminRenderer="booleanBadge";
}