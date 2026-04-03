import { UmbControllerBase } from "@umbraco-cms/backoffice/class-api";
import type { UmbControllerHost } from "@umbraco-cms/backoffice/controller-api";
import {
  __TEMPLATE_WORKSPACE_DATASOURCE_CLASS__,
} from "./__TEMPLATE_NAMESPACE_KEBAB__.datasource.js";
import type {
  __TEMPLATE_DATASOURCE_INTERFACE__,
} from "./__TEMPLATE_NAMESPACE_KEBAB__.datasource.js";

export class __TEMPLATE_WORKSPACE_REPOSITORY_CLASS__ extends UmbControllerBase {
  #dataSource: __TEMPLATE_DATASOURCE_INTERFACE__;

  constructor(
    host: UmbControllerHost,
    dataSource?: __TEMPLATE_DATASOURCE_INTERFACE__,
  ) {
    super(host);
    this.#dataSource =
      dataSource ?? new __TEMPLATE_WORKSPACE_DATASOURCE_CLASS__(this);
  }

  ping() {
    return this.#dataSource.ping();
  }

  whatsMyName() {
    return this.#dataSource.whatsMyName();
  }

  whatsTheTimeMrWolf() {
    return this.#dataSource.whatsTheTimeMrWolf();
  }

  whoAmI() {
    return this.#dataSource.whoAmI();
  }
}

export default __TEMPLATE_WORKSPACE_REPOSITORY_CLASS__;
