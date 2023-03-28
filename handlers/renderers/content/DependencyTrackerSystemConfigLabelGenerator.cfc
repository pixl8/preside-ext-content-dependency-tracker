component {

	property name="presideObjectService" inject="presideObjectService";

	private string function default( event, rc, prc, args={} ){
		var recordId = args.data ?: "";
		var record   = presideObjectService.selectData( objectName="system_config", id=recordId, selectFields=[ "category", "setting" ] );
		var category = record.category ?: "";
		var setting  = record.setting  ?: recordId;

		return category & ":" & setting;
	}
}