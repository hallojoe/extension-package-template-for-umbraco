export const manifests: Array<UmbExtensionManifest> = [
  {
    name: "__TEMPLATE_NAMESPACE_DISPLAY_NAME__ Workspace Context",
    alias: "__TEMPLATE_PROJECTS_NAMESPACE__.WorkspaceContext",
    type: "globalContext",
    js: () => import("./__TEMPLATE_NAMESPACE_KEBAB__.context.js"),
  },
];
