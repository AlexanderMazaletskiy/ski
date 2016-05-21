//
//  GameScene.swift
//  Ski
//
//  Created by Ralf Tappmeyer on 4/9/16.
//  Copyright (c) 2016 Ralf Tappmeyer. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, tileMapDelegate, SKPhysicsContactDelegate {
    // World
    var worldGenerator = tileMap()
    var worldLayer = SKNode()
    
    var guiLayer = SKNode()
    var overlayLayer = SKNode()
    
    // State Machine
    lazy var stateMachine: GKStateMachine = GKStateMachine(states: [
        GameSceneInitialState(scene: self),
        GameSceneActiveState(scene: self),
        GameScenePausedState(scene: self),
        GameSceneLimboState(scene: self),
        GameSceneWonState(scene: self),
        GameSceneLoseState(scene: self)
        ]
    )
    
    // Entities
    var entities = Set<GKEntity>()
    
    // Movement
    var movement = CGPointZero
    var beginTouchLocation = CGPointZero
    
    // Timers
    var lastUpdateTimeInterval: NSTimeInterval = 0
    let maximumUpdateDeltaTime: NSTimeInterval = 1.0 / 60.0
    var lastDeltaTime: NSTimeInterval = 0
    
    // Performance Info
    var score = 0
    var startTime = NSDate()
    var timeLimitSeconds = 60
    
    var tapState = tapAction.startGame
    
    lazy var componentSystems: [GKComponentSystem] = {
        //let animationSystem = GKComponentSystem(componentClass: AnimationComponent.self)
        let playerMoveSystem = GKComponentSystem(componentClass: PlayerMoveComponent.self)
        return [playerMoveSystem]
    }()

    // Sounds
    let soundInitial = SKAction.playSoundFileNamed("Skiier_Start", waitForCompletion: false)
    let soundFinish = SKAction.playSoundFileNamed("Skiier_Finish", waitForCompletion: false)
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        
        print(size.width)
        // Delegates
        worldGenerator.delegate = self
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector.zero
        
        // Setup Camera
        let myCamera = SKCameraNode()
        camera = myCamera
        addChild(myCamera)
        updateCameraScale()
        
        // Config World
        addChild(worldLayer)
        camera!.addChild(guiLayer)
        guiLayer.addChild(overlayLayer)
        
        // Gamestate
        stateMachine.enterState(GameSceneInitialState.self)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        /* Called when a touch begins */
        
        if touches.count > 0  {
            switch tapState {
            case .startGame:
                print("timer starts now")
                startTime = NSDate()
                stateMachine.enterState(GameSceneActiveState.self)
                break
            case .steerPlayer:
                for touch in touches {
                    //let key = String.init(format:"%d", touch)
                    beginTouchLocation = touch.locationInNode(self)
                }
                break
            case .dismissPause:
                stateMachine.enterState(GameSceneActiveState.self)
                break
            default:
                break
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        /* Called when a touch moved */
        if touches.count > 0 {
            for touch in touches {
                //let key = String.init(format:"%d", touch)
                let dragLocation = touch.locationInNode(self)
                if (dragLocation.x - beginTouchLocation.x >= 100 || dragLocation.x - beginTouchLocation.x <= -100) {
                    // Dragged too far, reset the location
                    beginTouchLocation = dragLocation
                } else {
                    let motion = CGPointMake((dragLocation.x - beginTouchLocation.x)/100, (dragLocation.y - beginTouchLocation.y)/100)
                    movement = motion
                }
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        //if touches.count > 0 {
            //for touch in touches {
                //let key = String.init(format:"%d", touch)
            //}
        //}
    }

   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
        if gameLoopPaused { return }
        
        // Calculate delta time
        var deltaTime = currentTime - lastUpdateTimeInterval
        deltaTime = deltaTime > maximumUpdateDeltaTime ? maximumUpdateDeltaTime : deltaTime
        lastUpdateTimeInterval = currentTime
        
        // Player controls
        if let player = worldLayer.childNodeWithName("playerNode") as? EntityNode, let playerEntity = player.entity as? PlayerEntity {
            if !(movement == CGPointZero) {
                playerEntity.moveComponent.movement = movement
            }
        }
        
        // Update all components
        for componentSystem in componentSystems {
            componentSystem.updateWithDeltaTime(deltaTime)
        }
        
        // Update camera position
        if let player = worldLayer.childNodeWithName("playerNode") as? EntityNode
        {
            var cameraPosition: CGPoint = player.position
            cameraPosition = CGPoint(x: ((size.width/2)*kScaleAmount) - 10, y: player.position.y - 60) // Adding 10 points buffer and 60 points offset to the top
            centerCameraOnPoint(cameraPosition)
        }
        
        // Update time display
        if let timeLabel = guiLayer.childNodeWithName("timeLabel") as? SKLabelNode {
            var seconds = Int(startTime.timeIntervalSinceNow) * -1
            var minutes = 0
            if seconds >= 60 {
                minutes = 1
                seconds -= 60
            }
            let minutesLabel = String(format: "%01d", minutes)
            let secondsLabel = String(format: "%02d", seconds)
            timeLabel.text = "\(minutesLabel):\(secondsLabel)"
            
        }
    }
    
    override func didFinishUpdate() {
        if let scoreLabel = guiLayer.childNodeWithName("scoreLabel") as? SKLabelNode {
            scoreLabel.text = String(score)
        }
        
    }
    
    func setupLevel() {
        // Generate Level
        worldGenerator.generateLevel(0)
        worldGenerator.createLevel()
        worldGenerator.presentLayerViaDelegate()
        
        // Add Labels
        let scoreTitleLabel = SKLabelNode(fontNamed: "Commodore-64-Pixelized")
        scoreTitleLabel.position = CGPoint(x: 480, y: 260)
        scoreTitleLabel.fontColor = UIColor.blackColor()
        scoreTitleLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Right
        scoreTitleLabel.name = "scoreTitleLabel"
        scoreTitleLabel.text = "SCORE"
        scoreTitleLabel.zPosition = 1000
        guiLayer.addChild(scoreTitleLabel)
        
        let scoreLabel = SKLabelNode(fontNamed: "Commodore-64-Pixelized")
        scoreLabel.position = CGPoint(x: 480, y: 230)
        scoreLabel.fontColor = UIColor.blackColor()
        scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Right
        scoreLabel.name = "scoreLabel"
        scoreLabel.text = "00"
        scoreLabel.zPosition = 1000
        guiLayer.addChild(scoreLabel)
        
        let timeTitleLabel = SKLabelNode(fontNamed: "Commodore-64-Pixelized")
        timeTitleLabel.position = CGPoint(x: 480, y: -30)
        timeTitleLabel.fontColor = UIColor.c64brownColor()
        timeTitleLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Right
        timeTitleLabel.name = "timeTitleLabel"
        timeTitleLabel.text = "TIME"
        timeTitleLabel.zPosition = 1000
        guiLayer.addChild(timeTitleLabel)
        
        let timeLabel = SKLabelNode(fontNamed: "Commodore-64-Pixelized")
        timeLabel.position = CGPoint(x: 480, y: -60)
        timeLabel.fontColor = UIColor.c64brownColor()
        timeLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Right
        timeLabel.name = "timeLabel"
        timeLabel.text = "00:00"
        timeLabel.zPosition = 1000
        guiLayer.addChild(timeLabel)
    }
    
    func createNodeOf(type type:tileType, location:CGPoint) {
        let atlasTiles = SKTextureAtlas(named: "world")
        switch type {
        case .tileAir:
            break
        case .tileSnow:
            break
        case .tileTree:
            let texture = atlasTiles.textureNamed("tree_30x32_00")
            texture.filteringMode = SKTextureFilteringMode.Nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 30, height: 32)
            node.position = location
            node.zPosition = 50
            node.physicsBody = SKPhysicsBody(rectangleOfSize: CGSize(width:8, height: 12), center: CGPointMake(0.0, -10.0) )
            node.physicsBody?.dynamic = true
            node.physicsBody?.categoryBitMask = ColliderType.Tree.rawValue
            node.physicsBody?.contactTestBitMask = ColliderType.Player.rawValue
            node.physicsBody?.collisionBitMask = ColliderType.None.rawValue
            node.name = "treeNode"
            worldLayer.addChild(node)
            break
        case .tileRock:
            let texture = atlasTiles.textureNamed("rock_16x12_00")
            texture.filteringMode = SKTextureFilteringMode.Nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 16, height: 12)
            node.position = location
            node.zPosition = 50
            node.physicsBody = SKPhysicsBody(rectangleOfSize: CGSize(width:14, height: 8), center: CGPointMake(0.0, -2.0) )
            node.physicsBody?.dynamic = true
            node.physicsBody?.categoryBitMask = ColliderType.Rock.rawValue
            node.physicsBody?.contactTestBitMask = ColliderType.Player.rawValue
            node.physicsBody?.collisionBitMask = ColliderType.None.rawValue
            node.name = "rockNode"
            worldLayer.addChild(node)
            break
        case .tilePost:
            let texture = atlasTiles.textureNamed("post_16x16_00")
            texture.filteringMode = SKTextureFilteringMode.Nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 16, height: 16)
            node.position = location
            node.zPosition = 50
            node.name = "postNode"
            worldLayer.addChild(node)
            
            let actionAnimation = SKAction.animateWithTextures([
                atlasTiles.textureNamed("post_16x16_00"),
                atlasTiles.textureNamed("post_16x16_01")
            ], timePerFrame: 0.2)
            node.runAction(SKAction.repeatActionForever(actionAnimation))
            break
        case .tileGate:
            let texture = atlasTiles.textureNamed("snow_16x32_00")
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 16, height: 2)
            node.position = CGPoint(x: location.x-4, y: location.y-7)
            node.zPosition = 5
            node.name = "gateNode"
            node.physicsBody = SKPhysicsBody(rectangleOfSize: CGSize(width: 16, height: 2))
            node.physicsBody?.categoryBitMask = ColliderType.Gate.rawValue
            node.physicsBody?.contactTestBitMask = ColliderType.Player.rawValue
            node.physicsBody?.collisionBitMask = ColliderType.None.rawValue
            node.physicsBody?.dynamic = true
            worldLayer.addChild(node)
            break
        case .tileStart:
            let playerEntity = PlayerEntity()
            let playerNode = playerEntity.spriteComponent.node
            playerNode.position = location
            playerNode.name = "playerNode"
            playerNode.zPosition = 10
            playerNode.anchorPoint = CGPointMake(0.5, 0.2)
            addEntity(playerEntity)

            var startCameraPosition: CGPoint = location
            startCameraPosition = CGPoint(x: ((size.width/2)*kScaleAmount) - 10, y: location.y - 60) // Adding 10 points buffer and 60 points offset to the top
            print(startCameraPosition)
            centerCameraOnPoint(startCameraPosition)
            break
        case .tileFinish:
            let texture = atlasTiles.textureNamed("finish_192x64_00")
            texture.filteringMode = SKTextureFilteringMode.Nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 192, height: 64)
            node.position = location
            node.zPosition = 50
            node.name = "finishNode"
            node.physicsBody = SKPhysicsBody(rectangleOfSize: CGSize(width: 192, height: 144), center: CGPoint(x: 0,y: 64))
            node.physicsBody?.categoryBitMask = ColliderType.Finish.rawValue
            node.physicsBody?.contactTestBitMask = ColliderType.Player.rawValue
            node.physicsBody?.collisionBitMask = ColliderType.None.rawValue
            node.physicsBody?.dynamic = true
            worldLayer.addChild(node)
            break
        default:
            break
        }
    }
    
    func addEntity(entity: GKEntity) {
        entities.insert(entity)
        if let spriteNode = entity.componentForClass(SpriteComponent.self)?.node {
            worldLayer.addChild(spriteNode)
        }
        for componentSystem in self.componentSystems {
            componentSystem.addComponentWithEntity(entity)
        }
    }
    
    // MARK: Camera controls
    
    func centerCameraOnPoint(point: CGPoint) {
        if let camera = camera {
            camera.position = point
        }
    }
    
    func updateCameraScale() {
        if let camera = camera {
            camera.setScale(kScaleAmount)
        }
    }
    
    // MARK: Physics contact
    
    func didBeginContact(contact: SKPhysicsContact) {
        let bodyA = contact.bodyA.node
        let bodyB = contact.bodyB.node
        
        // Did Player reach the finish line?
        if bodyA?.name == "finishNode" && bodyB?.name == "playerNode" {
            stateMachine.enterState(GameSceneFinishState.self)
            movement = CGPointZero
            runAction(SKAction.playSoundFileNamed("Skiier_Finish.m4a", waitForCompletion: false))
        }
        // Did Player pass through a gate?
        if bodyA?.name == "gateNode" {
            if bodyB?.name == "playerNode" {
                score = score + 100                
                let scoreLabel = SKLabelNode(fontNamed: "Commodore-64-Pixelized")
                scoreLabel.position = (bodyA?.position)!
                scoreLabel.fontColor = UIColor.blackColor()
                scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Center
                scoreLabel.text = "100"
                scoreLabel.zPosition = 99
                scoreLabel.setScale(kScaleAmount)
                worldLayer.addChild(scoreLabel)
            }
        }
        // Did Player hit a tree or rock?
        if bodyA?.name == "treeNode" || bodyA?.name == "rockNode" {
            if bodyB?.name == "playerNode" {
                stateMachine.enterState(GameSceneLimboState.self)
                // Turn off collisions while crash is in progress
                bodyB?.physicsBody?.contactTestBitMask = 0
                bodyB?.physicsBody?.collisionBitMask = 0
                bodyB?.physicsBody?.categoryBitMask = 0
                // Player fall animation sequence
                let atlasTiles = SKTextureAtlas(named: "player")
                bodyB!.runAction(SKAction.animateWithTextures([
                    atlasTiles.textureNamed("skiier_crash_18x17_00"),
                    atlasTiles.textureNamed("skiier_crash_21x13_01"),
                    atlasTiles.textureNamed("skiier_crash_23x10_02"),
                    atlasTiles.textureNamed("skiier_crash_24x15_03"),
                    SKTexture(), SKTexture(), SKTexture(), SKTexture(),
                    SKTexture(), SKTexture(), SKTexture(), SKTexture(),
                    SKTexture(), SKTexture(), SKTexture(), SKTexture()
                    ], timePerFrame: 0.25, resize: true, restore: true))
                // Player sliding down while falling
                bodyB!.runAction(SKAction.moveToY(bodyB!.position.y - 48, duration: 1))
                // Camera jolt sequence
                if let camera = camera {
                    let joltUp = CGPoint(x: camera.position.x, y: camera.position.y - 2)
                    let joltDown = CGPoint(x: camera.position.x, y: camera.position.y + 2)
                    self.runAction(SKAction.sequence([
                        SKAction.runBlock({ self.centerCameraOnPoint(joltUp) }), SKAction.waitForDuration(0.05),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltDown) }), SKAction.waitForDuration(0.10),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltUp) }), SKAction.waitForDuration(0.05),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltDown) }), SKAction.waitForDuration(0.15),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltUp) }), SKAction.waitForDuration(0.05),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltDown) }), SKAction.waitForDuration(0.20),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltUp) }), SKAction.waitForDuration(0.05),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltDown) }), SKAction.waitForDuration(0.25),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltUp) }), SKAction.waitForDuration(0.05),
                        SKAction.runBlock({ self.centerCameraOnPoint(joltDown) }), SKAction.waitForDuration(0.30)
                    ]))
                }
                // Wait for 4 seconds then restart
                self.runAction(SKAction.sequence([SKAction.waitForDuration(4), SKAction.runBlock({ () -> Void in
                    // Remove the tree/rock the player crashed into
                    bodyA!.removeFromParent()
                    // Reset the movement (joystick)
                    self.movement = CGPointZero
                    // Move the player back up to where it crashed
                    bodyB!.position.y = bodyB!.position.y + 48
                    // Turn collisions back on
                    bodyB?.physicsBody?.categoryBitMask = ColliderType.Player.rawValue
                    bodyB?.physicsBody?.collisionBitMask = ColliderType.None.rawValue
                    bodyB?.physicsBody?.contactTestBitMask = ColliderType.Gate.rawValue | ColliderType.Tree.rawValue | ColliderType.Rock.rawValue
                    self.stateMachine.enterState(GameSceneActiveState.self)
                })]))
            }
        }
    }

}
