//
//  ContentView.swift
//  AudioKit3DDemo
//
//  Created by Stanley Rosenbaum on 3/3/23.
//

import SwiftUI
import Combine
import AudioKit
import AudioKitUI
import AudioToolbox
import Keyboard
import SoundpipeAudioKit
import SwiftUI
import Tonic
import SceneKit
import AVFoundation


final class AudioKit3DVM: ObservableObject {
	@Published var conductor = AudioEngine3DConductor()
	@Published var coordinator = SceneCoordinator()

	let didComplete = PassthroughSubject<AudioKit3DVM, Never>()

	init() {
		coordinator.updateAudioSourceNodeDelegate = conductor
	}

}

protocol UpdateAudioSourceNodeDelegate {
	func updateListenerPosition3D(_ position3D: AVAudio3DPoint)
	func updateListenerOrientationVector(_ vector: AVAudio3DVectorOrientation)
	func updateListenerOrientationAngular(_ angular: AVAudio3DAngularOrientation)
	func updateSoundSourcePosition(_ position3D: AVAudio3DPoint)
}


class AudioEngine3DConductor: ObservableObject, ProcessesPlayerInput, UpdateAudioSourceNodeDelegate {
	let engine = AudioEngine()
	var player = AudioPlayer()
	let buffer: AVAudioPCMBuffer

	var source1mixer3D = Mixer3D(name: "AudioPlayer Mixer")
	var environmentalNode = EnvironmentalNode()

	init() {
		buffer = Cookbook.sourceBuffer
		player.buffer = buffer
		player.isLooping = true

		source1mixer3D.addInput(player)
		source1mixer3D.pointSourceInHeadMode = .mono

		environmentalNode.renderingAlgorithm = .auto
		environmentalNode.reverbParameters.loadFactoryReverbPreset(.largeHall2)
		environmentalNode.reverbBlend = 0.75
		environmentalNode.connect(mixer3D: source1mixer3D)
		environmentalNode.outputType = .externalSpeakers

		engine.output = environmentalNode

		engine.mainMixerNode?.pan = 1.0

		print(engine.avEngine)

	}

	deinit {
		player.stop()
		engine.stop()
	}

	func updateListenerPosition3D(_ position3D: AVAudio3DPoint) {
		environmentalNode.listenerPosition = position3D
	}


	func updateListenerOrientationVector(_ orientationVectors: AVAudio3DVectorOrientation) {
		environmentalNode.listenerVectorOrientation = AVAudio3DVectorOrientation(
			forward: orientationVectors.forward,
			up: orientationVectors.up)
	}

	func updateListenerOrientationAngular(_ angular: AVAudio3DAngularOrientation) {
		print("NOT USING")
	}

	func updateSoundSourcePosition(_ position3D: AVAudio3DPoint) {
        print(position3D)
		source1mixer3D.position = position3D
	}

}



class SceneCoordinator: NSObject, SCNSceneRendererDelegate, ObservableObject {

	var showsStatistics: Bool = false
	var debugOptions: SCNDebugOptions = []

	var updateAudioSourceNodeDelegate: UpdateAudioSourceNodeDelegate?

	lazy var theScene: SCNScene = {
		// create a new scene
		let scene = SCNScene(named: "searrl.scnassets/audio3DTest.scn")!
		return scene
	}()

	var cameraNode: SCNNode? {
		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.position = SCNVector3(x: 0, y: 1, z: 0)
		return cameraNode
	}

	func moveRight() {

	}

	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

		if let pointOfView = renderer.pointOfView,
		   let soundSource = renderer.scene?.rootNode.childNode(withName: "soundSource", recursively: true) {

            updateAudioSourceNodeDelegate?.updateSoundSourcePosition(AVAudio3DPoint(
                x: soundSource.presentation.worldPosition.x,
                y: soundSource.presentation.worldPosition.y,
                z: soundSource.presentation.worldPosition.z))

			updateAudioSourceNodeDelegate?.updateListenerPosition3D(AVAudio3DPoint(
				x: pointOfView.position.x,
				y: pointOfView.position.y,
				z: pointOfView.position.z))

			updateAudioSourceNodeDelegate?.updateListenerOrientationVector(AVAudio3DVectorOrientation(
				forward: AVAudio3DVector(
					x: pointOfView.forward.x,
					y: pointOfView.forward.y,
					z: pointOfView.forward.z),
				up: AVAudio3DVector(
					x: pointOfView.up.x,
					y: pointOfView.up.y,
					z: pointOfView.up.z)
			))

		}

		renderer.showsStatistics = self.showsStatistics
		renderer.debugOptions = self.debugOptions

	}

}



struct AudioKit3DView: View {
	@StateObject var vm = AudioKit3DVM()
	//	@StateObject var conductor = AudioEngine3DConductor()
	//	@StateObject var coordinator = SceneCoordinator()
	@Environment(\.colorScheme) var colorScheme

	var body: some View {
		VStack {
			PlayerControls(conductor: vm.conductor)
			HStack {
				ForEach(vm.conductor.player.parameters) {
					ParameterRow(param: $0)
				}
			}
			.padding(5)
			.frame(width: 600, height: 100, alignment: .center)
			Spacer()
			VStack {
				SceneView(
					scene: vm.coordinator.theScene,
					pointOfView: vm.coordinator.cameraNode,
					options: [
						.allowsCameraControl,
					],
					delegate: vm.coordinator
				)
			}
			.frame(
				minWidth: 0,
				maxWidth: .infinity,
				minHeight: 0,
				maxHeight: .infinity,
				alignment: .center)
			Spacer()
		}.cookbookNavBarTitle("SSO Oscillator")
			.onAppear {
				vm.conductor.start()
			}
			.onDisappear {
				vm.conductor.stop()
			}
			.background(colorScheme == .dark ?
						Color.clear : Color(red: 0.9, green: 0.9, blue: 0.9))
	}
}

struct AudioKit3DView_Previews: PreviewProvider {
	static var previews: some View {
		AudioKit3DView(vm: AudioKit3DVM())
			.previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro"))
			.previewDisplayName("iPhone 12 Pro")
			.previewInterfaceOrientation(.landscapeRight)
	}
}


extension SCNNode {
	/**
	 The Camera forward orientation vector as vector_float3.
	 */
	var forward: vector_float3 {
		get {
			return vector_float3(self.transform.m31,
								 self.transform.m32,
								 self.transform.m33)
		}
	}

	/**
	 The Camera up orientation vector as vector_float3.
	 */
	var up: vector_float3 {
		get {

			return vector_float3(self.transform.m21,
								 self.transform.m22,
								 self.transform.m23)
		}
	}
}
