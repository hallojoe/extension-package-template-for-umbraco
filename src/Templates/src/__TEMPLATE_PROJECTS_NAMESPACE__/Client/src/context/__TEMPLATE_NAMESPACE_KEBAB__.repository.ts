import { UmbControllerBase } from "@umbraco-cms/backoffice/class-api";
import type { UmbControllerHost } from "@umbraco-cms/backoffice/controller-api";
import {
  __TEMPLATE_NAMESPACE_COMPACT__WorkspaceDataSource,
} from "./__TEMPLATE_NAMESPACE_KEBAB__.datasource.js";
import type {
  __TEMPLATE_NAMESPACE_COMPACT__DataSource,
} from "./__TEMPLATE_NAMESPACE_KEBAB__.datasource.js";

export class __TEMPLATE_NAMESPACE_COMPACT__WorkspaceRepository extends UmbControllerBase {
  #dataSource: __TEMPLATE_NAMESPACE_COMPACT__DataSource;

  constructor(
    host: UmbControllerHost,
    dataSource?: __TEMPLATE_NAMESPACE_COMPACT__DataSource,
  ) {
    super(host);
    this.#dataSource =
      dataSource ?? new __TEMPLATE_NAMESPACE_COMPACT__WorkspaceDataSource(this);
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

export default __TEMPLATE_NAMESPACE_COMPACT__WorkspaceRepository;
