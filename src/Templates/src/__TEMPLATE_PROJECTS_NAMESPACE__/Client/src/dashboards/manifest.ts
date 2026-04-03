export const manifests: Array<UmbExtensionManifest> = [
  {
    name: "__TEMPLATE_NAMESPACE_DISPLAY_NAME__ Dashboard Alternative",
    alias: "__TEMPLATE_PROJECTS_NAMESPACE__.DashboardAlternative",
    type: "dashboard",
    js: () => import("./dashboard-alternative.element.js"),
    meta: {
      label: "Example Dashboard Alternative",
      pathname: "example-dashboard-alternative",
    },
    conditions: [
      {
        alias: "Umb.Condition.SectionAlias",
        match: "Umb.Section.Content",
      },
    ],
  },
  {
    name: "__TEMPLATE_NAMESPACE_DISPLAY_NAME__ Dashboard",
    alias: "__TEMPLATE_PROJECTS_NAMESPACE__.Dashboard",
    type: "dashboard",
    js: () => import("./dashboard.element.js"),
    meta: {
      label: "Example Dashboard",
      pathname: "example-dashboard",
    },
    conditions: [
      {
        alias: "Umb.Condition.SectionAlias",
        match: "Umb.Section.Content",
      },
    ],
  },  
];
