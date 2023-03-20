component {

	private string function default( event, rc, prc, args={} ){
		var label = args.data ?: "";

		if ( listLen( label, ":" ) != 2 ) {
			return label;
		}

		var category = listFirst( label, ":" );
		var setting  = listLast(  label, ":" );

		var categoryName = translateResource( uri="system-config.#category#:name"                 , defaultValue=category );
		var settingName  = translateResource( uri="system-config.#category#:field.#setting#.title", defaultValue=""  );

		settingName = isEmpty( settingName ) ? translateResource( uri="system-config.#category#:#setting#.label", defaultValue=setting ) : settingName; // legacy support

		return categoryName & ": " & settingName;
	}
}