component {

	property name="presideObjectService" inject="presideObjectService";

	private string function default( event, rc, prc, args={} ){
		var recordId = args.data ?: "";
		var record   = presideObjectService.selectData( objectName="system_config", id=recordId, selectFields=[ "category" ] );
		var category = record.category ?: "";
		var qs       = "";

		if ( len( category ) ) {
			qs = "id=#category#";
		}

		return event.buildAdminLink( linkto="sysconfig.category", queryString=qs );
	}
}