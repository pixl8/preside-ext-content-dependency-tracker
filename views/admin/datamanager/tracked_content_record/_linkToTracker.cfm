<cfscript>
	id          = args.id ?: 0;
	dependsOn   = numberFormat( args.depends_on_count   ?: 0 );
	dependentBy = numberFormat( args.dependent_by_count ?: 0 );
</cfscript>
<cfoutput>
	<li>
		<a id="dependencyTrackerMenuItem" href="#event.buildAdminLink( objectName="tracked_content_record", recordId=id )#" title="#translateResource( uri="preside-objects.tracked_content_record:linkToTracker.tooltip", data=[ dependsOn, dependentBy ] )#">
			<i class="fa fa-code-fork"></i>
			<span class="badge">#dependsOn#/#dependentBy#</span>
		</a>
	</li>
</cfoutput>