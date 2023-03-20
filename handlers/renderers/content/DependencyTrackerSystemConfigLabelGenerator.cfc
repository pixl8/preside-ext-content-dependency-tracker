component {

	property name="presideObjectService" inject="presideObjectService";

	private string function default( event, rc, prc, args={} ){
		var objectId = args.data ?: "";
		var record   = presideObjectService.selectData( objectName="system_config", id=objectId, selectFields=[ "category", "setting" ] );
		var category = record.category ?: "";
		var setting  = record.setting  ?: objectId;

		return category & ":" & setting;
	}
}