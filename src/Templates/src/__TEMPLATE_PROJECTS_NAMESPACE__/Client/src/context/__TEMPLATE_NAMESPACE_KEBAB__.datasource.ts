import { UmbControllerBase } from "@umbraco-cms/backoffice/class-api";
import type { UmbControllerHost } from "@umbraco-cms/backoffice/controller-api";
import {
  __TEMPLATE_NAMESPACE_COMPACT__Service,
} from "../api/index.js";

export interface __TEMPLATE_NAMESPACE_COMPACT__DataSource {
  ping(): ReturnType<typeof __TEMPLATE_NAMESPACE_COMPACT__Service.ping>;
  whatsMyName(): ReturnType<typeof __TEMPLATE_NAMESPACE_COMPACT__Service.whatsMyName>;
  whatsTheTimeMrWolf(): ReturnType<typeof __TEMPLATE_NAMESPACE_COMPACT__Service.whatsTheTimeMrWolf>;
  whoAmI(): ReturnType<typeof __TEMPLATE_NAMESPACE_COMPACT__Service.whoAmI>;
}

export class __TEMPLATE_NAMESPACE_COMPACT__WorkspaceDataSource
  extends UmbControllerBase
  implements __TEMPLATE_NAMESPACE_COMPACT__DataSource
{
  constructor(host: UmbControllerHost) {
    super(host);
  }

  ping() {
    return __TEMPLATE_NAMESPACE_COMPACT__Service.ping();
  }

  whatsMyName() {
    return __TEMPLATE_NAMESPACE_COMPACT__Service.whatsMyName();
  }

  whatsTheTimeMrWolf() {
    return __TEMPLATE_NAMESPACE_COMPACT__Service.whatsTheTimeMrWolf();
  }

  whoAmI() {
    return __TEMPLATE_NAMESPACE_COMPACT__Service.whoAmI();
  }
}

export default __TEMPLATE_NAMESPACE_COMPACT__WorkspaceDataSource;
