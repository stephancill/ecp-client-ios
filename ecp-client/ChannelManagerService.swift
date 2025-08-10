//
//  ChannelManagerService.swift
//  ecp-client
//
//  Restored by Assistant on 2025/08/10.
//

import Foundation
import BigInt
#if !Web3CocoaPods
import Web3
#endif
import Web3ContractABI

// MARK: - Channel Manager Contract Interface

public protocol ChannelManagerContract: EthereumContract {
    func getChannel(channelId: BigUInt) -> SolidityInvocation
    func getCommentCreationFee() -> SolidityInvocation
    func getHookTransactionFee() -> SolidityInvocation
    func calculateMsgValueWithHookFee(postFeeAmountForwardedToHook: BigUInt) -> SolidityInvocation
}

open class GenericChannelManagerContract: StaticContract, ChannelManagerContract {
    public var address: EthereumAddress?
    public let eth: Web3.Eth

    open var constructor: SolidityConstructor?
    open var events: [SolidityEvent] { [] }

    public required init(address: EthereumAddress?, eth: Web3.Eth) {
        self.address = address
        self.eth = eth
    }
}

public extension ChannelManagerContract {
    func getChannel(channelId: BigUInt) -> SolidityInvocation {
        // tuple(string name,string description,address hook, tuple(bool,bool,bool,bool,bool,bool) permissions)
        let permissionsType = SolidityType.tuple([
            .bool, .bool, .bool, .bool, .bool, .bool
        ])
        // Some decoders are more stable when flattening the tuple components into outputs
        let outputs = [
            SolidityFunctionParameter(name: "name", type: .string),
            SolidityFunctionParameter(name: "description", type: .string),
            SolidityFunctionParameter(name: "hook", type: .address),
            SolidityFunctionParameter(name: "permissions", type: permissionsType)
        ]
        let inputs = [
            SolidityFunctionParameter(name: "channelId", type: .uint256)
        ]
        let method = SolidityConstantFunction(name: "getChannel", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(channelId)
    }

    func getCommentCreationFee() -> SolidityInvocation {
        let method = SolidityConstantFunction(name: "getCommentCreationFee", inputs: [], outputs: [SolidityFunctionParameter(name: "", type: .uint96)], handler: self)
        return method.invoke()
    }

    func getHookTransactionFee() -> SolidityInvocation {
        let method = SolidityConstantFunction(name: "getHookTransactionFee", inputs: [], outputs: [SolidityFunctionParameter(name: "", type: .uint16)], handler: self)
        return method.invoke()
    }

    func calculateMsgValueWithHookFee(postFeeAmountForwardedToHook: BigUInt) -> SolidityInvocation {
        let inputs = [SolidityFunctionParameter(name: "postFeeAmountForwardedToHook", type: .uint256)]
        let outputs = [SolidityFunctionParameter(name: "", type: .uint256)]
        let method = SolidityConstantFunction(name: "calculateMsgValueWithHookFee", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(postFeeAmountForwardedToHook)
    }
}

// Minimal read-only Hook contract interface to retrieve commentFee
public protocol HookContract: EthereumContract {
    func commentFee() -> SolidityInvocation
}

open class GenericHookContract: StaticContract, HookContract {
    public var address: EthereumAddress?
    public let eth: Web3.Eth

    open var constructor: SolidityConstructor?
    open var events: [SolidityEvent] { [] }

    public required init(address: EthereumAddress?, eth: Web3.Eth) {
        self.address = address
        self.eth = eth
    }
}

public extension HookContract {
    func commentFee() -> SolidityInvocation {
        let method = SolidityConstantFunction(name: "commentFee", inputs: [], outputs: [SolidityFunctionParameter(name: "", type: .uint256)], handler: self)
        return method.invoke()
    }
}

// MARK: - Service

@MainActor
public final class ChannelManagerService: ObservableObject {
    @Published public private(set) var isLoadingFee: Bool = false
    @Published public private(set) var feeError: String?
    @Published public private(set) var channelIdToFeeWei: [UInt64: BigUInt] = [:]
    @Published public private(set) var channelIdStringToFeeWei: [String: BigUInt] = [:]
    @Published public private(set) var channelIdToHookAddress: [UInt64: String] = [:]

    private let web3: Web3
    private let contract: GenericChannelManagerContract

    // Channel Manager address
    private let managerAddress: String = "0xa1043eDBE1b0Ffe6C12a2b8ed5AfD7AcB2DEA396"

    public init(rpcURL: String = "https://mainnet.base.org") {
        self.web3 = Web3(rpcURL: rpcURL)
        do {
            let address = try EthereumAddress(hex: managerAddress, eip55: true)
            self.contract = web3.eth.Contract(type: GenericChannelManagerContract.self, address: address)
        } catch {
            fatalError("Failed to initialize ChannelManagerService: \(error)")
        }
    }

    // Compute total payable post fee for a channel id (uint256)
    private func computePostFeeWei(bigChannelId: BigUInt, hookAddressOverride: String? = nil) async throws -> BigUInt {
        print("🔎 [ChannelFee] compute start bigChannelId=\(bigChannelId)")
        // Short-circuit: channel id 0 => no fee
        if bigChannelId == 0 {
            print("✅ [ChannelFee] bigChannelId=0 fee=0")
            return 0
        }

        // Step 1: getChannel -> hook address
        let hookAddress: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            print("🔎 [ChannelFee] Calling getChannel(\(bigChannelId))")
            if let override = hookAddressOverride, !override.isEmpty {
                print("✅ [ChannelFee] Using override hook=\(override)")
                continuation.resume(returning: override)
                return
            }
            contract.getChannel(channelId: bigChannelId).call { result, error in
                if let error = error {
                    print("❌ [ChannelFee] getChannel error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                if let hookAddr = result?["hook"] as? EthereumAddress {
                    let hex = hookAddr.hex(eip55: true)
                    print("✅ [ChannelFee] getChannel hook=\(hex)")
                    continuation.resume(returning: hex)
                } else if let addr = result?["2"] as? EthereumAddress {
                    // Fallback on index
                    let hex = addr.hex(eip55: true)
                    print("✅ [ChannelFee] getChannel hook (fallback)=\(hex)")
                    continuation.resume(returning: hex)
                } else if let flat = result?[""] as? [Any], flat.count >= 3, let addr = flat[2] as? EthereumAddress {
                    let hex = addr.hex(eip55: true)
                    print("✅ [ChannelFee] getChannel hook (flat)=\(hex)")
                    continuation.resume(returning: hex)
                } else {
                    print("❌ [ChannelFee] getChannel invalid response: \(String(describing: result))")
                    continuation.resume(throwing: NSError(domain: "ChannelManagerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid getChannel response - cannot extract hook address"]))
                }
            }
        }
        print("🔎 [ChannelFee] Hook address=\(hookAddress)")
        if isZeroAddress(hookAddress) {
            print("✅ [ChannelFee] Zero hook address -> fee=0")
            return 0
        }

        // Step 2: read commentFee from Hook contract
        print("🔎 [ChannelFee] Preparing hook EthereumAddress from string=\(hookAddress)")
        // Use eip55: false to tolerate non-checksummed addresses from API
        let hookEthAddress = try EthereumAddress(hex: hookAddress, eip55: false)
        print("✅ [ChannelFee] hook EthereumAddress=\(hookEthAddress.hex(eip55: true))")
        let hookContract = web3.eth.Contract(type: GenericHookContract.self, address: hookEthAddress)
        let commentFeeWei: BigUInt = try await withCheckedThrowingContinuation { (c: CheckedContinuation<BigUInt, Error>) in
            print("🔎 [ChannelFee] Calling hook.commentFee() at \(hookAddress)")
            hookContract.commentFee().call { result, error in
                if let error = error { print("❌ [ChannelFee] hook.commentFee error: \(error)"); c.resume(throwing: error); return }
                print("🔎 [ChannelFee] hook.commentFee raw=\(String(describing: result))")
                if let v = result?[""] as? BigUInt {
                    print("✅ [ChannelFee] hook.commentFee=\(v)")
                    c.resume(returning: v)
                } else if let vIdx = result?["0"] as? BigUInt {
                    print("✅ [ChannelFee] hook.commentFee (idx)=\(vIdx)")
                    c.resume(returning: vIdx)
                } else {
                    let err = NSError(domain: "ChannelManagerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid commentFee response"])
                    print("❌ [ChannelFee] hook.commentFee invalid -> \(err)")
                    c.resume(throwing: err)
                }
            }
        }

        // Step 3: read manager fees (tolerate server errors -> fallback to 0)
        let commentCreationFee: BigUInt = (try? await withCheckedThrowingContinuation { (c: CheckedContinuation<BigUInt, Error>) in
            print("🔎 [ChannelFee] Calling manager.getCommentCreationFee()")
            contract.getCommentCreationFee().call { result, error in
                if let error = error {
                    print("❌ [ChannelFee] getCommentCreationFee error: \(error)")
                    c.resume(throwing: error)
                    return
                }
                print("🔎 [ChannelFee] getCommentCreationFee raw=\(String(describing: result))")
                if let v = result?[""] as? BigUInt {
                    print("✅ [ChannelFee] getCommentCreationFee=\(v)")
                    c.resume(returning: v)
                } else if let vU96 = result?["0"] as? BigUInt {
                    print("✅ [ChannelFee] getCommentCreationFee (idx)=\(vU96)")
                    c.resume(returning: vU96)
                } else {
                    let err = NSError(domain: "ChannelManagerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid getCommentCreationFee"])
                    print("❌ [ChannelFee] getCommentCreationFee invalid -> \(err)")
                    c.resume(throwing: err)
                }
            }
        }) ?? 0

        // Step 4: compute total using helper for hook portion (fallback to manual BPS if server error)
        let hookPortionWithProtocol: BigUInt
        do {
            hookPortionWithProtocol = try await withCheckedThrowingContinuation { (c: CheckedContinuation<BigUInt, Error>) in
                print("🔎 [ChannelFee] Calling manager.calculateMsgValueWithHookFee(\(commentFeeWei))")
                contract.calculateMsgValueWithHookFee(postFeeAmountForwardedToHook: commentFeeWei).call { result, error in
                    if let error = error {
                        print("❌ [ChannelFee] calculateMsgValueWithHookFee error: \(error)")
                        c.resume(throwing: error)
                        return
                    }
                    print("🔎 [ChannelFee] calculateMsgValueWithHookFee raw=\(String(describing: result))")
                    if let v = result?[""] as? BigUInt {
                        print("✅ [ChannelFee] hookPortionWithProtocol=\(v)")
                        c.resume(returning: v)
                    } else if let vIdx = result?["0"] as? BigUInt {
                        print("✅ [ChannelFee] hookPortionWithProtocol (idx)=\(vIdx)")
                        c.resume(returning: vIdx)
                    } else {
                        let err = NSError(domain: "ChannelManagerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid calculateMsgValueWithHookFee"])
                        print("❌ [ChannelFee] calculateMsgValueWithHookFee invalid -> \(err)")
                        c.resume(throwing: err)
                    }
                }
            }
        } catch {
            print("⚠️ [ChannelFee] Falling back to manual BPS calculation due to error: \(error)")
            // getHookTransactionFee bps
            let bps: BigUInt
            do {
                bps = try await withCheckedThrowingContinuation { (c: CheckedContinuation<BigUInt, Error>) in
                    contract.getHookTransactionFee().call { result, error in
                        if let error = error { print("❌ [ChannelFee] getHookTransactionFee error: \(error)"); c.resume(throwing: error); return }
                        if let v = result?[""] as? BigUInt { c.resume(returning: v) }
                        else if let v0 = result?["0"] as? BigUInt { c.resume(returning: v0) }
                        else { c.resume(throwing: NSError(domain: "ChannelManagerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid getHookTransactionFee"])) }
                    }
                }
            } catch {
                print("⚠️ [ChannelFee] getHookTransactionFee failed, defaulting bps to 0")
                bps = 0
            }
            let denom: BigUInt = 10_000 - bps
            let numer = commentFeeWei * 10_000
            hookPortionWithProtocol = (numer + (denom - 1)) / denom
            print("✅ [ChannelFee] manual hookPortionWithProtocol=\(hookPortionWithProtocol) using bps=\(bps)")
        }

        let total = commentCreationFee + hookPortionWithProtocol
        print("✅ [ChannelFee] totalFeeWei=\(total)")
        return total
    }

    // Loads total payable post fee for a single channel and caches it by numeric id
    public func loadPostFeeWei(for channelId: UInt64, hookAddress: String? = nil) async {
        isLoadingFee = true
        feeError = nil
        print("🔎 [ChannelFee] Start loadPostFeeWei channelId=\(channelId)")
        do {
            let total = try await computePostFeeWei(bigChannelId: BigUInt(integerLiteral: channelId), hookAddressOverride: hookAddress)
            channelIdToFeeWei[channelId] = total
            print("✅ [ChannelFee] cached numeric fee channelId=\(channelId) fee=\(total)")
        } catch {
            print("❌ [ChannelFee] loadPostFeeWei failed: \(error)")
            feeError = "Failed to fetch fee: \(error.localizedDescription)"
        }
        isLoadingFee = false
        print("🔎 [ChannelFee] End loadPostFeeWei channelId=\(channelId)")
    }

    // Convenience: load fee by string id (supports decimal or hex representations, up to 256 bits)
    public func loadPostFeeWei(channelIdString: String, hookAddress: String? = nil) async {
        await MainActor.run { self.isLoadingFee = true; self.feeError = nil }
        let trimmed = channelIdString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try decimal first
        if let dec = BigUInt(trimmed, radix: 10) {
            if dec == 0 {
                await MainActor.run { self.channelIdStringToFeeWei[channelIdString] = 0; self.channelIdToFeeWei[0] = 0; self.isLoadingFee = false }
                return
            }
            do {
                let total = try await computePostFeeWei(bigChannelId: dec, hookAddressOverride: hookAddress)
                await MainActor.run { self.channelIdStringToFeeWei[channelIdString] = total }
                if let u64 = UInt64(dec.description) {
                    await MainActor.run { self.channelIdToFeeWei[u64] = total }
                }
                print("✅ [ChannelFee] cached string fee id=\(channelIdString) fee=\(total)")
                await MainActor.run { self.isLoadingFee = false }
            } catch {
                await MainActor.run { self.feeError = error.localizedDescription; self.isLoadingFee = false }
            }
            return
        }
        // Try hex with or without 0x
        let lower = trimmed.lowercased()
        let hexBody = lower.hasPrefix("0x") ? String(lower.dropFirst(2)) : lower
        if let hexVal = BigUInt(hexBody, radix: 16) {
            if hexVal == 0 {
                await MainActor.run { self.channelIdStringToFeeWei[channelIdString] = 0; self.channelIdToFeeWei[0] = 0; self.isLoadingFee = false }
                return
            }
            do {
                let total = try await computePostFeeWei(bigChannelId: hexVal, hookAddressOverride: hookAddress)
                await MainActor.run { self.channelIdStringToFeeWei[channelIdString] = total }
                if let u64 = UInt64(hexVal.description) {
                    await MainActor.run { self.channelIdToFeeWei[u64] = total }
                }
                print("✅ [ChannelFee] cached string fee id=\(channelIdString) fee=\(total)")
                await MainActor.run { self.isLoadingFee = false }
            } catch {
                await MainActor.run { self.feeError = error.localizedDescription; self.isLoadingFee = false }
            }
            return
        }
        await MainActor.run { self.feeError = "Invalid channel id format"; self.isLoadingFee = false }
    }

    public func feeWei(for channelId: UInt64) -> BigUInt? {
        channelIdToFeeWei[channelId]
    }

    public func feeWei(forChannelIdString channelIdString: String) -> BigUInt? {
        channelIdStringToFeeWei[channelIdString]
    }

    // Simple formatter for ETH value with up to 6 decimals
    public func formatWeiToEthString(_ wei: BigUInt) -> String {
        let base = BigUInt(10).power(18)
        let integerPart = wei / base
        let fractional = wei % base

        // Zero-pad fractional to 18 digits, then take up to 6 and trim trailing zeros
        var fractionalString = String(fractional)
        if fractionalString.count < 18 {
            fractionalString = String(repeating: "0", count: 18 - fractionalString.count) + fractionalString
        }
        var short = String(fractionalString.prefix(6))
        while short.last == "0" && !short.isEmpty { short.removeLast() }
        let fractionalDisplay = short.isEmpty ? "0" : short

        return "\(integerPart).\(fractionalDisplay) ETH"
    }

    private func isZeroAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "0x0000000000000000000000000000000000000000" { return true }
        if trimmed == "0x0" { return true }
        // Tolerate missing 0x and leading zeros
        let hexBody = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        return Set(hexBody).isSubset(of: ["0"]) && !hexBody.isEmpty
    }
}

