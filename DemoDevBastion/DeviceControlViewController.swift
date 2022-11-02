//
//  DeviceControlViewController.swift
//  DemoDevBastion
//
//  Created by Роман Елфимов on 20.04.2021.
//

import UIKit
import CocoaMQTT
import Firebase

final class DeviceControlViewController: UITableViewController {
    
    // MARK: - Public Properties
    
    public var isDirectly: Bool = false
    public var devUID: String = ""
    
    // MARK: - Private Properties
    
    private var ref: DatabaseReference!
    private var deviceUID: String = "" // при подключении напрямую приходит с предыдущего экрана, при автоматической авторизации приходит из Firebase
    private var accessLevel: String = "0"
    
    private var mqtt: CocoaMQTT!
    private var globalTopic: String = ""
    
    // MARK: - Outlets
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    
    @IBOutlet weak var ledOneSwitch: UISwitch!
    @IBOutlet weak var ledTwoSwitch: UISwitch!
    @IBOutlet weak var ledThreeSwitch: UISwitch!
    @IBOutlet weak var ledFourSwitch: UISwitch!
    @IBOutlet weak var buzerButton: UIButton!
    @IBOutlet weak var openPrivateOfficeButton: UIBarButtonItem!
    
    // MARK: - LifeCycle
    // Для получения данных создадим наблюдателя
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
    
        if isDirectly {
            self.deviceUID = self.devUID
            
        } else {
            guard let currentUser = Auth.auth().currentUser else { return }
            ref = Database.database().reference(withPath: "users")
            
            ref.observe(.value) { (snapshot) in
                var level: String = ""
                var uid: String = ""
                
                for item in snapshot.children {
                    // Получаем данные
                    let userData = User(snapshot: item as! DataSnapshot)
                    
                    if userData.userID == currentUser.uid {
                        uid = userData.deviceUID
                        level = userData.accessLevel
                    }
                }
                self.deviceUID = uid
                self.accessLevel = level
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // Удаляем наблюдателя по выходу
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !isDirectly {
            ref.removeAllObservers()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        let logo = UIImage(named: "logo")
        setTitle("DemoDev", andImage: logo!)
        
        setupMQTT()
        connectAck()
        receiveMessage()
        
        tableView.tableFooterView = UIView()
        buzerButton.layer.cornerRadius = buzerButton.frame.size.height / 2
        buzerButton.clipsToBounds = true
    }
    
    // MARK: - Actions
    
    @IBAction func ledOneSwitchTapped(_ sender: UISwitch) {
        publishSwitchMessage(led: "led01", sender: sender)
    }
    
    @IBAction func ledTwoSwitchTapped(_ sender: UISwitch) {
        publishSwitchMessage(led: "led02", sender: sender)
    }
    
    @IBAction func ledThreeSwitchTapped(_ sender: UISwitch) {
        publishSwitchMessage(led: "led03", sender: sender)
    }
    
    @IBAction func ledFourSwitchTapped(_ sender: UISwitch) {
        publishSwitchMessage(led: "led04", sender: sender)
    }
    
    @IBAction func buzerButtonTapped(_ sender: Any) {
        
        let message = CocoaMQTTMessage(topic: "FF01/\(deviceUID)/\(accessLevel)/0123456789/req/buzer", string: "1")
        mqtt.publish(message)
    }
    
    @IBAction func openPrivateOfficeButtonTapped(_ sender: Any) {
        
        // Добавить проверку на то, есть ли аккаунт, если нет, показывать только ячейку "Забыть устройство"
        if isDirectly {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let privateOfficeVC = storyboard.instantiateViewController(identifier: "ForgetDirectlyDeviceViewController") as? ForgetDirectlyDeviceViewController else { return }
            navigationController?.pushViewController(privateOfficeVC, animated: true)
            
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let privateOfficeVC = storyboard.instantiateViewController(identifier: "PrivateOfficeTableViewController") as? PrivateOfficeTableViewController else { return }
            navigationController?.pushViewController(privateOfficeVC, animated: true)
        }
        
    }
    
    // MARK: - Private Methods
    
    private func setupMQTT() {
        
        let clientId = "CocoaMQTT-" + String(ProcessInfo().processIdentifier)
        
        let host: String = "test.mosquitto.org"
        let port: UInt16 = 1883
        
        mqtt = CocoaMQTT(clientID: clientId, host: host, port: port)
        mqtt.keepAlive = 60
        mqtt.connect()
    }
    
    private func connectAck() {
        mqtt.didConnectAck = { [weak self] _, _ in
            guard let self = self else { return }
        
            self.globalTopic = "FF01/\(self.deviceUID)/"
            let top = self.globalTopic + "#"
            self.mqtt.subscribe(top)

        }
    }
    
    private func receiveMessage() {
        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            
            guard let self = self else { return }
            
            if !message.topic.contains("FF01") {
                let alertController = UIAlertController(title: "Устройство отключено", message: "Проверьте устройство", preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
                alertController.addAction(alertAction)
                self.present(alertController, animated: true, completion: nil)
            }
            
            let topic = message.topic
            guard let msgString = message.string else { return }
            
            if topic == "\(self.globalTopic)data/outputs/led01" {
                DispatchQueue.main.async {
                    if msgString == "0" {
                        self.ledOneSwitch.isOn = false
                    } else {
                        self.ledOneSwitch.isOn = true
                    }
                }
            } else if topic == "\(self.globalTopic)data/outputs/led02" {
                DispatchQueue.main.async {
                    if msgString == "0" {
                        self.ledTwoSwitch.isOn = false
                    } else {
                        self.ledTwoSwitch.isOn = true
                    }
                }
                
            } else if topic == "\(self.globalTopic)data/outputs/led03" {
                DispatchQueue.main.async {
                    if msgString == "0" {
                        self.ledThreeSwitch.isOn = false
                    } else {
                        self.ledThreeSwitch.isOn = true
                    }
                }
            } else if topic == "\(self.globalTopic)data/outputs/led04" {
                DispatchQueue.main.async {
                    if msgString == "0" {
                        self.ledFourSwitch.isOn = false
                    } else if msgString == "1" {
                        self.ledFourSwitch.isOn = true
                    }
                }
            }
            
            guard let data = msgString.data(using: .utf8) else { return }
            let stateResponse = try? JSONDecoder().decode(Model.self, from: data)
            guard let state = stateResponse?.state else {
                return
            }
            
            if state == "offline" {
        
                let alertController = UIAlertController(title: "Нет свзяи с устройством", message: "", preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "Ок", style: .default, handler: nil)
                
                alertController.addAction(alertAction)
                self.present(alertController, animated: true) {
                    
                    // Либо сделать это по нажатию на Ок
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.ledOneSwitch.isOn = false
                        self.ledTwoSwitch.isOn = false
                        self.ledThreeSwitch.isOn = false
                        self.ledFourSwitch.isOn = false
                    }
                }
            }
        }
        
    }
    
    private func publishSwitchMessage(led: String, sender: UISwitch) {
        var stringMessage = ""
        
        if sender.isOn {
            stringMessage = "1"
        } else {
            stringMessage = "0"
        }
        
        let message = CocoaMQTTMessage(topic: "FF01/\(deviceUID)/\(accessLevel)/0123456789/req/\(led)", string: stringMessage)
        mqtt.publish(message)
        
        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            
            guard let self = self else { return }
            if message.topic == "FF01/\(self.deviceUID)/\(self.accessLevel)/0123456789/res" {
                
                guard let msgString = message.string else { return }
                guard let data = msgString.data(using: .utf8) else { return }
                
                let firstResponse = try? JSONDecoder().decode(FirstResponseModel.self, from: data)
                let secondResponse = try? JSONDecoder().decode(SecondResponseModel.self, from: data)
                
                guard let secondRespnonseResult = secondResponse?.result else { return }
                if secondRespnonseResult != "ok" {
                    DispatchQueue.main.async {
                        
                        let alertController = UIAlertController(title: "Ошибка", message: "Не удалось внести изменения", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "Ок", style: .default, handler: nil)
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - TableView Data Source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if accessLevel == "2" {
            if indexPath.row == 4 {
                return 0
            } else if indexPath.row == 5 {
                return 0
            }
            
        } else if accessLevel == "4" {
            
            if indexPath.row == 2 {
                return 0
            } else if indexPath.row == 3 {
                return 0
            } else if indexPath.row == 4 {
                return 0
            } else if indexPath.row == 5 {
                return 0
            }
        }
        
        return tableView.estimatedRowHeight
    }
    
}
