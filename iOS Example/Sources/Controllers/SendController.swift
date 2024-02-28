import Combine
import HsExtensions
import SnapKit
import TronKit
import UIKit

class SendController: UIViewController {
    private let adapter: TrxAdapter = Manager.shared.adapter
    private let estimatedFeeLimit: Int? = nil
    private var cancellables = Set<AnyCancellable>()

    private let addressTextField = UITextField()
    private let amountTextField = UITextField()
    private let gasPriceLabel = UILabel()
    private let sendButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Send TRX"

        let addressLabel = UILabel()

        view.addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide).inset(16)
        }

        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .gray
        addressLabel.text = "Address:"

        let addressTextFieldWrapper = UIView()

        view.addSubview(addressTextFieldWrapper)
        addressTextFieldWrapper.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(addressLabel.snp.bottom).offset(8)
        }

        addressTextFieldWrapper.borderWidth = 1
        addressTextFieldWrapper.borderColor = .black.withAlphaComponent(0.1)
        addressTextFieldWrapper.layer.cornerRadius = 8

        addressTextFieldWrapper.addSubview(addressTextField)
        addressTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        addressTextField.text = Configuration.shared.defaultSendAddress
        addressTextField.font = .systemFont(ofSize: 13)

        let amountLabel = UILabel()

        view.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(addressTextFieldWrapper.snp.bottom).offset(24)
        }

        amountLabel.font = .systemFont(ofSize: 14)
        amountLabel.textColor = .gray
        amountLabel.text = "Amount:"

        let amountTextFieldWrapper = UIView()

        view.addSubview(amountTextFieldWrapper)
        amountTextFieldWrapper.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(amountLabel.snp.bottom).offset(8)
        }

        amountTextFieldWrapper.borderWidth = 1
        amountTextFieldWrapper.borderColor = .black.withAlphaComponent(0.1)
        amountTextFieldWrapper.layer.cornerRadius = 8

        amountTextFieldWrapper.addSubview(amountTextField)
        amountTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        amountTextField.font = .systemFont(ofSize: 13)

        let ethLabel = UILabel()

        view.addSubview(ethLabel)
        ethLabel.snp.makeConstraints { make in
            make.leading.equalTo(amountTextFieldWrapper.snp.trailing).offset(16)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(amountTextFieldWrapper)
        }

        ethLabel.font = .systemFont(ofSize: 13)
        ethLabel.textColor = .black
        ethLabel.text = "TRX"

        view.addSubview(gasPriceLabel)
        gasPriceLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(amountTextFieldWrapper.snp.bottom).offset(24)
        }

        gasPriceLabel.font = .systemFont(ofSize: 12)
        gasPriceLabel.textColor = .gray

        view.addSubview(sendButton)
        sendButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(gasPriceLabel.snp.bottom).offset(24)
        }

        sendButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        sendButton.setTitleColor(.systemBlue, for: .normal)
        sendButton.setTitleColor(.lightGray, for: .disabled)
        sendButton.setTitle("Send", for: .normal)
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        addressTextField.addTarget(self, action: #selector(updateEstimatedFee), for: .editingChanged)
        amountTextField.addTarget(self, action: #selector(updateEstimatedFee), for: .editingChanged)

        updateEstimatedFee()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        view.endEditing(true)
    }

    @objc private func updateEstimatedFee() {
        guard let addressHex = addressTextField.text?.trimmingCharacters(in: .whitespaces),
              let valueText = amountTextField.text,
              let value = Int(valueText),
              value > 0
        else {
            return
        }

        guard let address = try? Address(address: addressHex) else {
            return
        }

        gasPriceLabel.text = "Loading..."

        let contract = adapter.transferContract(toAddress: address, value: value)

        Task { [weak self, adapter] in
            do {
                let fees = try await adapter.estimateFee(contract: contract)

                self?.sendButton.isEnabled = value > 0

                var feeStrings = [String]()
                for fee in fees {
                    let feeString: String

                    switch fee {
                    case let .bandwidth(points, price): feeString = "\((Decimal(points * price) / 1_000_000).description)TRX (\(points) Bandwidth)"
                    case let .energy(required, price): feeString = "\((Decimal(required * price) / 1_000_000).description)TRX (\(required) Energy)"
                    case let .accountActivation(amount): feeString = "\((Decimal(amount) / 1_000_000).description)TRX (Account Activation)"
                    }

                    feeStrings.append(feeString)
                }

                self?.gasPriceLabel.text = feeStrings.joined(separator: " | ")
            } catch {
                print(error)
            }
        }
    }

    @objc private func send() {
        guard let addressHex = addressTextField.text?.trimmingCharacters(in: .whitespaces) else {
            return
        }

        guard let address = try? Address(address: addressHex) else {
            show(error: "Invalid address")
            return
        }

        guard let valueText = amountTextField.text, let value = Int(valueText), value > 0 else {
            show(error: "Invalid amount")
            return
        }

        let contract = adapter.transferContract(toAddress: address, value: value)

        Task { [weak self, adapter, estimatedFeeLimit] in
            do {
                try await adapter.send(contract: contract, feeLimit: estimatedFeeLimit)
                self?.handleSuccess(address: address, amount: value)
            } catch {
                self?.show(error: "Send failed: \(error)")
            }
        }
    }

    @MainActor
    private func show(error: String) {
        let alert = UIAlertController(title: "Send Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    @MainActor
    private func handleSuccess(address: Address, amount: Int) {
        addressTextField.text = ""
        amountTextField.text = ""

        let alert = UIAlertController(title: "Success", message: "\(amount) sent to \(address)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}
