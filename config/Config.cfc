component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.features.contentDependencyTracker      = { enabled=true , siteTemplates=[ "*" ], widgets=[] };
		settings.features.globalLinkToDependencyTracker = { enabled=false, siteTemplates=[ "*" ], widgets=[] };

		settings.adminConfigurationMenuItems.append( "dependencyTracker" );

		settings.adminMenuItems.dependencyTracker = {
			  buildLinkArgs = { objectName="tracked_content_record" }
			, activeChecks  = { datamanagerObject="tracked_content_record" }
			, icon          = "fa-code-fork"
			, title         = "cms:dependencyTracker.navigation.link"
		};

		conf.interceptors.prepend( { class="app.extensions.preside-ext-content-dependency-tracker.interceptors.ContentDependencyTrackerInterceptor", properties={} } );

		settings.contentDependencyTracker = {
			  autoEnableDbTextFields  = false
			, autoTrackRelatedObjects = false
			, linkToTrackerView = "/admin/datamanager/tracked_content_record/_linkToTracker"
			, trackObjects = {
				  asset                  = { enabled=true }
				, site                   = { enabled=true }
				, rules_engine_condition = { enabled=true }
				, page = {
					  enabled    = true
					, properties = {
						  main_content = { enabled=true  }
						, parent_page  = { enabled=false }
						, site         = { enabled=false }
					}
				}
				, system_config = {
					  enabled                = true
					, hideIrrelevantRecords  = true
					, labelGenerator         = "dependencyTrackerSystemConfigLabelGenerator"
					, labelRenderer          = "dependencyTrackerSystemConfigLabelRenderer"
					, viewRecordLinkRenderer = "dependencyTrackerSystemConfigLinkRenderer"
					, properties             = {
						  value = { enabled=true }
						, site  = { enabled=false }
					}
				}
				, email_layout_config_item = {
					  enabled                = true
					, hideIrrelevantRecords  = true
					, properties             = {
						value = { enabled=true }
					}
				}
				, accessDenied                     = { enabled=true  }
				, forgotten_password               = { enabled=true  }
				, homepage                         = { enabled=true  }
				, login                            = { enabled=true  }
				, notFound                         = { enabled=true  }
				, reset_password                   = { enabled=true  }
				, standard_page                    = { enabled=true  }
				, password_policy                  = { enabled=true  }
				, email_blueprint                  = { enabled=true  }
				, asset_version                    = { enabled=false }
				, asset_meta                       = { enabled=false }
				, asset_derivative                 = { enabled=false }
				, asset_folder                     = { enabled=true  }
				, email_template_shortened_link    = { enabled=false }
				, log_entry                        = { enabled=false }
				, site_alias_domain                = { enabled=false }
				, site_redirect_domain             = { enabled=false }
				, server_error                     = { enabled=false }
				, url_redirect_rule                = { enabled=false }
				, security_user_site               = { enabled=false }
				, saved_export                     = { enabled=false }
				, rest_user                        = { enabled=false }
				, website_user                     = { enabled=false }
				, website_user_action              = { enabled=false }
				, admin_notification               = { enabled=false }
				, admin_notification_topic         = { enabled=false }
				, workflow_state                   = { enabled=false }
				, formbuilder_form                 = { enabled=true  }
				, formbuilder_formaction           = { enabled=true  }
				, formbuilder_formitem             = { enabled=true  }
				, formbuilder_formsubmission       = { enabled=false }
				, formbuilder_question             = { enabled=true  }
				, formbuilder_question_response    = { enabled=false }
				, email_mass_send_queue            = { enabled=false }
				, email_template_send_log          = { enabled=false }
				, email_template_send_log_activity = { enabled=false }
			}
			, linkToTrackerEvents = {
				  "admin.datamanager.viewRecord"                      = { objectNameParam="object"     , recordIdParam="id"       }
				, "admin.datamanager.editRecord"                      = { objectNameParam="object"     , recordIdParam="id"       }
				, "admin.assetmanager.editAsset"                      = { objectName="asset"           , recordIdParam="asset"    }
				, "admin.sites.editSite"                              = { objectName="site"            , recordIdParam="id"       }
				, "admin.sitetree.editPage"                           = { objectName="page"            , recordIdParam="id"       }
				, "admin.emailcenter.systemTemplates.template"        = { objectName="email_template"  , recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.edit"            = { objectName="email_template"  , recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.configurelayout" = { objectName="email_template"  , recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.stats"           = { objectName="email_template"  , recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.logs"            = { objectName="email_template"  , recordIdParam="template" }
				, "admin.emailCenter.customTemplates.preview"         = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.edit"            = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.settings"        = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.configureLayout" = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.stats"           = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.logs"            = { objectName="email_template"  , recordIdParam="id"       }
				, "admin.formbuilder.editForm"                        = { objectName="formbuilder_form", recordIdParam="id"       }
				, "admin.formbuilder.submissions"                     = { objectName="formbuilder_form", recordIdParam="id"       }
				, "admin.formbuilder.actions"                         = { objectName="formbuilder_form", recordIdParam="id"       }
				, "admin.formbuilder.manageform"                      = { objectName="formbuilder_form", recordIdParam="id"       }
			}
		};

		settings.enum.dependencyTrackerObjectNames = StructKeyArray( settings.contentDependencyTracker.trackObjects );
	}
}