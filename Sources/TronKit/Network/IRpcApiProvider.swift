protocol IRpcApiProvider {
    func fetch<T>(rpc: JsonRpc<T>) async throws -> T
}
