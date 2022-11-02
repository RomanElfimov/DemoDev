//
//  ActiveDevicesListViewController.swift
//  DemoDevBastion
//
//  Created by Роман Елфимов on 19.04.2021.
//

import UIKit
import CocoaMQTT
import Firebase

final class ActiveDevicesListViewController: UIViewController {
    
    // MARK: - Public Property
    
    public var isDirectly: Bool = false // Если подключаемся напрямую
    
    // MARK: - Private Properties
    
    private var mqtt: CocoaMQTT!
    private var devicesUIDsArray: [String] = [] // массив, т.к. устройств может быть несколько

    private var ref: DatabaseReference!
    
    // MARK: - Outlet
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMQTT()
        connectAck()
        receiveMessage()
        
        tableView.tableFooterView = UIView()
        
        guard let currentUser = Auth.auth().currentUser else { return }
        ref = Database.database().reference(withPath: "users").child(currentUser.uid)
        
    }
    
    // MARK: - Private Methods
    
    private func setupMQTT() {
        let clientId = "CocoaMQTT-" + String(ProcessInfo().processIdentifier)
        let host: String = "test.mosquitto.org"
        let port: UInt16 = 1883
        
        mqtt = CocoaMQTT(clientID: clientId, host: host, port: port)
        mqtt.connect()
    }
    
    private func connectAck() {
        mqtt.didConnectAck = { _, _ in
            self.mqtt.subscribe("FF01/#")
        }
    }
    
    private func receiveMessage() {
        mqtt.didReceiveMessage = { [weak self] mqtt, message, _ in
            guard let self = self else { return }
            
            guard let msgString = message.string else { return }
            guard let data = msgString.data(using: .utf8) else { return }
            let stateResponse = try? JSONDecoder().decode(Model.self, from: data)
            guard let state = stateResponse?.state else {
                return
            }
            
            if state == "ready" {
                let uid = message.topic[5..<21]
                self.devicesUIDsArray.append(uid)
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
                mqtt.disconnect()
            } else if state == "offline" {
                // show alert
                let alertController = UIAlertController(title: "Нет свзяи с устройством", message: "", preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "Ок", style: .default, handler: nil)
                
                alertController.addAction(alertAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
}

// MARK: - Extension UITableView

extension ActiveDevicesListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devicesUIDsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = devicesUIDsArray[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        guard let navVC = storyboard.instantiateViewController(identifier: "DeviceControlViewController") as? UINavigationController else { return }
        guard let deviceControlVC = navVC.viewControllers.first as? DeviceControlViewController else { return }
        
        if !isDirectly {
            ref.updateChildValues(["deviceUID": devicesUIDsArray[indexPath.row]])
        } else {
            deviceControlVC.isDirectly = true
            deviceControlVC.devUID = devicesUIDsArray[indexPath.row]
        }
        
        present(navVC, animated: true, completion: nil)
    }
}
