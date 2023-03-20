<cfscript>
	id          = args.id ?: 0;
	dependsOn   = numberFormat( args.depends_on_count   ?: 0 );
	dependentBy = numberFormat( args.dependent_by_count ?: 0 );
</cfscript>
<cfoutput>
	<div class="pull-right">
		&nbsp;&nbsp;&nbsp;<i class="fa fa-fw fa-exchange"></i>
		<a href="#event.buildAdminLink( objectName="tracked_content_object", recordId=id )#" title="#translateResource( uri="preside-objects.tracked_content_object:linkToTracker.tooltip", data=[ dependsOn, dependentBy ] )#">
			#translateResource( "preside-objects.tracked_content_object:linkToTracker.label" )# <span class="badge">#dependsOn#/#dependentBy#</span>
		</a>
	</div>
</cfoutput>