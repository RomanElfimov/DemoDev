//
//  SignInViewController.swift
//  DemoDevBastion
//
//  Created by Роман Елфимов on 20.04.2021.
//

import UIKit
import Firebase

final class SignInViewController: UIViewController {

    // MARK: - Private Properties
    
    private var ref: DatabaseReference!
    private var deviceUID: String = ""
    
    // MARK: - Outlets
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var signInButton: UIButton!
    
    // MARK: - LifeCycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        emailTextField.text = ""
        passwordTextField.text = ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        signInButton.backgroundColor = .clear
        signInButton.layer.cornerRadius = 5
        signInButton.layer.borderWidth = 1
        signInButton.layer.borderColor = UIColor(named: "BastColor")?.cgColor
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    // MARK: - Actions
    
    @IBAction func signInButtonTapped(_ sender: Any) {
        
        guard let email = emailTextField.text, email != "", let password = passwordTextField.text, password != "" else {
            let alertController = UIAlertController(title: "Некорректные данные", message: "", preferredStyle: .alert)
            let alertAction = UIAlertAction(title: "Ок", style: .cancel, handler: nil)
            alertController.addAction(alertAction)
            present(alertController, animated: true, completion: nil)
            
            return
        }
        
        // Логинимся
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (user, error) in
            // Если возникла ошибка
            if error != nil {
                print("Возникла ошибка \(error?.localizedDescription)")
                return
            }
            
            // Проверяем существование пользователя
            // Пользователь есть
            if user != nil {
                
                guard let currentUser = Auth.auth().currentUser else { return }
                self?.ref = Database.database().reference(withPath: "users")// .child(currentUser.uid)
                self?.ref.observe(.value) { (snapshot) in

                    for item in snapshot.children {
                        let userData = User(snapshot: item as! DataSnapshot) // получаем пользователя
                        self?.deviceUID = userData.deviceUID // смотрbм deviceUID пользователя

                        // Если deviceUID нету, предлагаем выбрать устройство из списка доступных

                        if userData.userID == currentUser.uid {

                            if self?.deviceUID == "" {

                                let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
                                guard let navVC = storyboard.instantiateViewController(identifier: "ActiveDevicesListViewController") as? UINavigationController else { return }
                                self?.present(navVC, animated: true, completion: nil)
                            } else {

                                // Если deviceUID есть, показываем экран управления
                                let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
                                guard let navVC = storyboard.instantiateViewController(identifier: "DeviceControlViewController") as? UINavigationController else { return }
                                self?.present(navVC, animated: true, completion: nil)
                            }
                        }
                    }
                }
            }
            // Пользователя нет
            print("failure")
        }
    }

    @IBAction func backTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - Extension UITexField

extension SignInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            passwordTextField.resignFirstResponder()
        }
        return true
    }
}
