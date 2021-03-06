//
//  PlayerEntity.swift
//  Ski
//
//  Created by Ralf Tappmeyer on 5/7/16.
//  Copyright © 2016 Ralf Tappmeyer. All rights reserved.
//

import SpriteKit
import GameplayKit

class PlayerEntity: GKEntity {
    // MARK: Properties
    
    var playerId: Int
    var elapsedTime: TimeInterval
    var score: Int
    var gateScoringMultiplier: Int
    
    var isCrashed: Bool
    var reachedFinishLine: Bool
    
    var renderComponent: RenderComponent {
        guard let renderComponent = component(ofType: RenderComponent.self) else { fatalError("A PlayerEntity must have a RenderComponent.") }
        return renderComponent
    }
    
    var animationComponent: AnimationComponent!
    
    init(playerId: Int) {
        self.playerId = playerId
        elapsedTime = 0
        score = 0
        gateScoringMultiplier = gateSettings.minScoringMultiplier
        
        isCrashed = false
        reachedFinishLine = false
        
        super.init()
        
        // Load and set the score (carry over the score from previous levelscene)
        score = loadScore()
        
        // Configure Components for this Entity
        
        let renderComponent = RenderComponent(entity: self)
        addComponent(renderComponent)
        
        let atlas = SKTextureAtlas(named: "player")
        let defaultTexture = atlas.textureNamed("idle__00.png")
        defaultTexture.filteringMode = SKTextureFilteringMode.nearest
        let size = CGSize(width: 16, height: 19)
        
        let spriteComponent = SpriteComponent(texture: defaultTexture, size: size)
        addComponent(spriteComponent)
        spriteComponent.node.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        
        let animationComponent = AnimationComponent(node: spriteComponent.node, textureSize: size, animations: loadAnimations())
        addComponent(animationComponent)
        
        let moveComponent = MoveComponent()
        addComponent(moveComponent)
        
        let physicsBody = SKPhysicsBody(circleOfRadius: 4)
        physicsBody.categoryBitMask = ColliderType.player.rawValue
        physicsBody.contactTestBitMask = ColliderType.gate.rawValue | ColliderType.obstacle.rawValue | ColliderType.finish.rawValue
            
        let physicsComponent = PhysicsComponent(physicsBody: physicsBody)
        addComponent(physicsComponent)
        
        let stateComponent = StateComponent(states: [
            PlayerAppearState(entity: self),
            PlayerInputControlledState(entity: self),
            PlayerCrashState(entity: self),
            PlayerReachedFinishLineState(entity: self)]
        )
        addComponent(stateComponent)
        
        // Connect the PhysicsComponent with the RenderComponent.
        renderComponent.node.physicsBody = physicsComponent.physicsBody
        
        // Connect the SpriteComponent with the RenderComponent
        renderComponent.node.addChild(spriteComponent.node)
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: GKEntity Life Cycle
    
    //override func update(deltaTime seconds: TimeInterval) {
    //    super.update(deltaTime: seconds)
    //    elapsedTime += seconds
    //}
    
    func loadAnimations() -> [AnimationState: Animation] {
        let textureAtlas = SKTextureAtlas(named: "player")
        var animations = [AnimationState: Animation]()
        animations[.idle] = AnimationComponent.animationFromAtlas(atlas: textureAtlas, withImageIdentifier: "idle", forAnimationState: .idle)
        animations[.left] = AnimationComponent.animationFromAtlas(atlas: textureAtlas, withImageIdentifier: "left", forAnimationState: .left)
        animations[.right] = AnimationComponent.animationFromAtlas(atlas: textureAtlas, withImageIdentifier: "right", forAnimationState: .right)
        animations[.crash] = AnimationComponent.animationFromAtlas(atlas: textureAtlas, withImageIdentifier: "crash", forAnimationState: .crash, repeatTexturesForever: false)
        return animations
    }
    
    func loadScore() -> Int {
        // Load the score stored in UserDefaults
        let defaults = UserDefaults.standard
        let scoreKeyConstant = "player\(playerId)_score"        // TODO: Multiplayer, lookout this is the correct player's score
        return defaults.integer(forKey: scoreKeyConstant)
    }
    
    func incrementScore(increment: Int) {
        // Increment the score and save it in UserDefaults
        if (increment > 0) {
            score += increment
            let defaults = UserDefaults.standard
            let scoreKeyConstant = "player\(playerId)_score"    // TODO: Multiplayer
            defaults.setValue(score, forKey: scoreKeyConstant)
        }
    }
    
    func resetScoreToZero() {
        // Reset the score stored in UserDefaults to 0
        let defaults = UserDefaults.standard
        let scoreKeyConstant = "player\(playerId)_score"        // TODO: Multiplayer
        defaults.setValue(0, forKey: scoreKeyConstant)
        self.score = 0
    }
    


}
