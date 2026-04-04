import { UmbContextBase } from "@umbraco-cms/backoffice/class-api";
import type { UmbControllerHost } from "@umbraco-cms/backoffice/controller-api";
import { UmbContextToken } from "@umbraco-cms/backoffice/context-api";
import { UmbObjectState } from "@umbraco-cms/backoffice/observable-api";
import type { UserModel } from "../api/index.js";
import { __TEMPLATE_NAMESPACE_COMPACT__WorkspaceRepository } from "./__TEMPLATE_NAMESPACE_KEBAB__.repository.js";

export const __TEMPLATE_NAMESPACE_UPPER_SNAKE__WORKSPACE_CONTEXT =
  new UmbContextToken<__TEMPLATE_NAMESPACE_COMPACT__WorkspaceContext>(
    "__TEMPLATE_PROJECTS_NAMESPACE__.WorkspaceContext",
  );

type WorkspaceResponse<TData> = {
  data?: TData;
  error?: unknown;
};

export class __TEMPLATE_NAMESPACE_COMPACT__WorkspaceContext extends UmbContextBase {
  #repository = new __TEMPLATE_NAMESPACE_COMPACT__WorkspaceRepository(this);

  #ping = new UmbObjectState<string | undefined>(undefined);
  readonly ping = this.#ping.asObservable();

  #name = new UmbObjectState<string | undefined>(undefined);
  readonly name = this.#name.asObservable();

  #time = new UmbObjectState<string | undefined>(undefined);
  readonly time = this.#time.asObservable();

  #user = new UmbObjectState<UserModel | undefined>(undefined);
  readonly user = this.#user.asObservable();

  #loading = new UmbObjectState<boolean>(false);
  readonly loading = this.#loading.asObservable();

  #error = new UmbObjectState<string>("");
  readonly error = this.#error.asObservable();

  constructor(host: UmbControllerHost) {
    super(host, __TEMPLATE_NAMESPACE_UPPER_SNAKE__WORKSPACE_CONTEXT);
  }

  async loadPing() {
    return this.#runRequest(
      () => this.#repository.ping(),
      (data) => this.#ping.setValue(data),
      "Failed to load ping response.",
    );
  }

  async loadName() {
    return this.#runRequest(
      () => this.#repository.whatsMyName(),
      (data) => this.#name.setValue(data),
      "Failed to load name.",
    );
  }

  async loadTime() {
    return this.#runRequest(
      () => this.#repository.whatsTheTimeMrWolf(),
      (data) => this.#time.setValue(data),
      "Failed to load time.",
    );
  }

  async loadUser() {
    return this.#runRequest(
      () => this.#repository.whoAmI(),
      (data) => this.#user.setValue(data),
      "Failed to load current user.",
    );
  }

  clearError() {
    this.#error.setValue("");
  }

  getPingValue() {
    return this.#ping.getValue();
  }

  getNameValue() {
    return this.#name.getValue();
  }

  getTimeValue() {
    return this.#time.getValue();
  }

  getUserValue() {
    return this.#user.getValue();
  }

  async #runRequest<TData>(
    action: () => Promise<WorkspaceResponse<TData>>,
    onSuccess: (data: TData) => void,
    errorMessage: string,
  ) {
    this.#loading.setValue(true);
    this.#error.setValue("");

    const response = await action();

    this.#loading.setValue(false);

    if (this.#hasError(response) || response.data === undefined) {
      this.#error.setValue(errorMessage);
      return response;
    }

    onSuccess(response.data);
    return response;
  }

  #hasError(response: object) {
    return "error" in response && Boolean((response as { error?: unknown }).error);
  }
}

export default __TEMPLATE_NAMESPACE_COMPACT__WorkspaceContext;
