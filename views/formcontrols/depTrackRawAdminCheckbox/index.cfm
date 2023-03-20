<cfscript>
	inputName    = args.name          ?: "";
	inputId      = args.id            ?: "";
	inputClass   = args.class         ?: "";
	defaultValue = args.defaultValue  ?: "";
	disabled     = isTrue( args.disabled ?: "" );
	value        = event.getValue( name=inputName, defaultValue=defaultValue );
	if ( not IsSimpleValue( value ) ) {
		value = "";
	}
	checked = isTrue( value );

</cfscript>

<cfoutput>
	<input type="checkbox" id="#inputId#" name="#inputName#" value="1" class="#inputClass# ace" tabindex="#getNextTabIndex()#" <cfif checked>checked</cfif><cfif disabled> disabled</cfif>>
</cfoutput>