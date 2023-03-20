<cfscript>
	args.control  = args.control ?: "";
	args.label    = args.label   ?: "";
	args.help     = args.help    ?: "";
	args.for      = args.for     ?: "";
	args.error    = args.error   ?: "";
	args.disabled = IsTrue( args.disabled ?: "" );

	hasError = Len( Trim( args.error ) );

	event.include( "/css/admin/specific/depTrackAdminCheckboxWithHelp/" );
</cfscript>

<cfoutput>
	<div class="form-group dep-track-admin-checkbox-with-help <cfif hasError> has-error</cfif><cfif args.disabled> disabled</cfif>">
		<div class="form-field">
			<div class="checkbox role-picker-radio">
				<label>
					#args.control#
					<span class="lbl<cfif args.disabled> grey</cfif>">
						<span class="role-title bigger">#args.label#</span><br />
						<cfif Len( Trim( args.help ) )>
							<cfif args.disabled>
								<em class="role-desc">#args.help#</em>
							<cfelse>
								<span class="role-desc">#args.help#</span>
							</cfif>
						</cfif>
					</span>

					<cfif hasError>
						<div for="#args.for#" class="help-block">#args.error#</div>
					</cfif>
				</label>
			</div>
		</div>
	</div>
</cfoutput>