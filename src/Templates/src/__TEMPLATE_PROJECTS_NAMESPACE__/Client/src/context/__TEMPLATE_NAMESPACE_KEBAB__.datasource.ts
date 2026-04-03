import { UmbControllerBase } from "@umbraco-cms/backoffice/class-api";
import type { UmbControllerHost } from "@umbraco-cms/backoffice/controller-api";
import {
  __TEMPLATE_SERVICE_NAME__,
} from "../api/index.js";

export interface __TEMPLATE_DATASOURCE_INTERFACE__ {
  ping(): ReturnType<typeof __TEMPLATE_SERVICE_NAME__.ping>;
  whatsMyName(): ReturnType<typeof __TEMPLATE_SERVICE_NAME__.whatsMyName>;
  whatsTheTimeMrWolf(): ReturnType<typeof __TEMPLATE_SERVICE_NAME__.whatsTheTimeMrWolf>;
  whoAmI(): ReturnType<typeof __TEMPLATE_SERVICE_NAME__.whoAmI>;
}

export class __TEMPLATE_WORKSPACE_DATASOURCE_CLASS__
  extends UmbControllerBase
  implements __TEMPLATE_DATASOURCE_INTERFACE__
{
  constructor(host: UmbControllerHost) {
    super(host);
  }

  ping() {
    return __TEMPLATE_SERVICE_NAME__.ping();
  }

  whatsMyName() {
    return __TEMPLATE_SERVICE_NAME__.whatsMyName();
  }

  whatsTheTimeMrWolf() {
    return __TEMPLATE_SERVICE_NAME__.whatsTheTimeMrWolf();
  }

  whoAmI() {
    return __TEMPLATE_SERVICE_NAME__.whoAmI();
  }
}

export default __TEMPLATE_WORKSPACE_DATASOURCE_CLASS__;
