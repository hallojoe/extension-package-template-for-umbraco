using Asp.Versioning;
using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;
using Umbraco.Cms.Api.Common.OpenApi;
using Umbraco.Cms.Api.Management.OpenApi;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.DependencyInjection;

namespace __TEMPLATE_PROJECTS_NAMESPACE__.Composers;

public class __TEMPLATE_NAMESPACE_COMPACT__ApiComposer : IComposer
{
    public void Compose(IUmbracoBuilder builder)
    {

        builder.Services.AddSingleton<IOperationIdHandler, __TEMPLATE_NAMESPACE_COMPACT__OperationHandler>();

        builder.Services.Configure<SwaggerGenOptions>(opt =>
        {
            // Related documentation:
            // URL: https://docs.umbraco.com/umbraco-cms/tutorials/creating-a-backoffice-api

            // Configure the Swagger generation options
            // Add in a new Swagger API document solely for our own package that can be browsed via Swagger UI
            // Along with having a generated swagger JSON file that we can use to auto generate a TypeScript client
            opt.SwaggerDoc(Constants.ApiName, new OpenApiInfo
            {
                Title = Constants.ApiTitle,
                Version = Constants.ApiVersion,
                Contact = new OpenApiContact
                {
                    Name = Constants.ApiAuthors,
                    Email = Constants.ApiContactEmail,
                    Url = new Uri(Constants.ApiOrganizationUrl)
                }
            });

            // Enable Umbraco authentication for the Swagger document
            // PR: https://github.com/umbraco/Umbraco-CMS/pull/15699
            opt.OperationFilter<__TEMPLATE_NAMESPACE_COMPACT__OperationSecurityFilter>();
        });
    }

    public class __TEMPLATE_NAMESPACE_COMPACT__OperationSecurityFilter : BackOfficeSecurityRequirementsOperationFilterBase
    {
        protected override string ApiName => Constants.ApiName;
    }

    // This is used to generate pretty operation IDs in our swagger JSON file.
    // So the generated TypeScript client has pretty method names and not too verbose
    // URL: https://docs.umbraco.com/umbraco-cms/tutorials/creating-a-backoffice-api/umbraco-schema-and-operation-ids#operation-ids
    public class __TEMPLATE_NAMESPACE_COMPACT__OperationHandler : OperationIdHandler
    {
        public __TEMPLATE_NAMESPACE_COMPACT__OperationHandler(IOptions<ApiVersioningOptions> apiVersioningOptions) : base(apiVersioningOptions)
        {
        }

        protected override bool CanHandle(ApiDescription apiDescription, ControllerActionDescriptor controllerActionDescriptor)
        {
            return controllerActionDescriptor.ControllerTypeInfo.Namespace?.StartsWith(Constants.ControllerNamespace, comparisonType: StringComparison.InvariantCultureIgnoreCase) is true;
        }

        public override string Handle(ApiDescription apiDescription) => $"{apiDescription.ActionDescriptor.RouteValues["action"]}";
    }
}




