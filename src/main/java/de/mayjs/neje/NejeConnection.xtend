package de.mayjs.neje

import java.awt.image.RenderedImage
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.nio.ByteBuffer
import java.nio.file.Files
import java.nio.file.Paths
import javafx.application.Platform
import javafx.beans.property.ObjectProperty
import javafx.beans.property.SimpleObjectProperty
import javafx.concurrent.Task
import javax.imageio.ImageIO
import org.apache.commons.io.input.TeeInputStream
import org.eclipse.xtend.lib.annotations.Accessors
import purejavacomm.CommPortIdentifier
import purejavacomm.PureJavaSerialPort
import xtendfx.beans.FXBindable

import static extension java.lang.Integer.toHexString
import static extension java.lang.String.format

@Accessors
class NejeState {
	// 0x01 - 0xff are reserved for normal states.
	public static val UNKNOWN = new NejeState("Unknown state.", 0x01)
	public static val DISCONNECTED = new NejeState("Disconnected.", 0x02)
	public static val CONNECTING = new NejeState("Connecting..", 0x03)
	public static val READY = new NejeState("Ready.", 0x04)
	public static val CLEARING = new NejeState("Clearing image from printer..", 0x05)
	public static val SENDING = new NejeState("Sending image to printer..", 0x06)
	public static val ENGRAVING = new NejeState("Engraving image..", 0x07)
	
	// 0x0100 marks that the state is an error state
	// error states occupy 0x0101 - 0x01ff
	public static val ERROR_HANDSHAKE = new NejeState("Error during handshake!", 0x101)
	public static val ERROR_UNKNOWN = new NejeState("Unknown error.", 0x102)
	public static val ERROR_CONNECTION_LOST = new NejeState("Connection to printer was lost!", 0x103)
		 
	private val String descriptor
	private val int nr
	 
	private new(String descriptor, int nr) {
	 	this.descriptor = descriptor
		this.nr = nr
	}
	 
	override equals(Object other) {
		if(other instanceof NejeState)
			nr == other.nr
		else false
	}
	
	def isError() {
		return nr.bitwiseAnd(0x100) > 0
	}
}

class NejeCommands {
	public static final val byte[] MOVE_TO_ORIGIN= #[0xf3.byteValue]
	public static final val byte[] OPEN = #[0xf6.byteValue]
	public static final val byte[] CLEAR_IMAGE = newByteArrayOfSize(8).map[0xfe.byteValue]
	public static final val byte[] START_ENGRAVING = #[0xf1.byteValue]
}

class NewNejeConnection {
	var PureJavaSerialPort port
	val ObjectProperty<NejeState> stateProperty = new SimpleObjectProperty(this, "state", NejeState.DISCONNECTED)
	var Task<Void> listenerTask
	val ByteBuffer buffer = ByteBuffer.allocate(10)
	
	def open(CommPortIdentifier identifier) {
		close
		// TODO: Set error state if this fails
		port = identifier.open("jneje", -1) as PureJavaSerialPort
		port.setSerialPortParams(57600, 8, 1, 0)
		
		listenerTask = new Task<Void>(){
			override protected call() throws Exception {
				while(!isCancelled) {
					while(port.inputStream.available==0)
						Thread.sleep(1)
					buffer.put(port.inputStream.read.byteValue)
					byteRead()
				}
				null
			}
		}
		val listenerThread = new Thread(listenerTask)
		listenerThread.daemon = true
		listenerThread.start
		
		state = NejeState.CONNECTING
		sendCommand(NejeCommands.OPEN)
	}

	/**
	 * Checks if we can do anything with the received bytes
	 */
	private def byteRead() {
		val NejeState newState = switch(state) {
			case NejeState.CONNECTING: {
				if(buffer.position == 2) {
					if(buffer.array.get(0) == 0x65 && buffer.array.get(1) == 0x6f) {
						buffer.rewind
						NejeState.READY
					} else if(buffer.array.get(0) == 0xff) {
						NejeState.ENGRAVING						
					} else {
						buffer.rewind
						NejeState.ERROR_HANDSHAKE	
					}	
				} else if(buffer.position == 1) {
					if(buffer.array.get(0) == 0xff) {
						NejeState.ENGRAVING
					} else if(buffer.array.get(0) != 0x65) {
						buffer.rewind
						NejeState.ERROR_HANDSHAKE
					}
				}
			}
			
			case NejeState.ENGRAVING: {
				
			}
		}
		if(newState !== null) Platform.runLater[state = newState]
	}
	
	def close() {
		
	}
	
	def stateProperty() {
		stateProperty
	}
	
	def getState() {
		stateProperty().get
	}
	
	def setState(NejeState state) {
		stateProperty().set(state)
	}
	
	private def sendCommand(byte[] command) {
		port.outputStream.write(command)
		port.outputStream.flush
	}
}

@FXBindable class NejeConnection {
	var PureJavaSerialPort port
//	private var Task<Void> listenerTask
	var String state = "Disconnected."
	var boolean isWaiting = false
	var boolean connected = false
	var boolean engravingInProgress = false
	
	var BufferedInputStream portInputStream
	var Task<Void> listenerTask
	
	def open(CommPortIdentifier identifier) {
		close
		val port = identifier.open("jneje", -1) as PureJavaSerialPort
		port.setSerialPortParams(57600, 8, 1, 0)
		setPort(port)
		
		
		val piped = new PipedInputStream
		val tee = new TeeInputStream(port.inputStream, new PipedOutputStream(piped))
		portInputStream = new BufferedInputStream(piped)
		
		// The code below can be used to output received bytes 		
		listenerTask = new Task<Void>(){
			override protected call() throws Exception {
				while(!isCancelled) {
					while(tee.available==0)
						Thread.sleep(1)
					handle(tee.read.byteValue)
					if(portInputStream.available > 10)
						portInputStream.read
				}
				null
			}
		}
		val listenerThread = new Thread(listenerTask)
		listenerThread.daemon = true
		listenerThread.start
		handshake
	}
	
	var byte[] buffer = newByteArrayOfSize(5)
	var int bufferPos = 0
	def handle(byte value) {
		if(value == 0xff.byteValue) {
			engravingInProgress = true
			Platform.runLater[
				state = "Engraving.."
			]
		}
		if(!engravingInProgress)
			println(value.toHexString)
		else {
			if(value == 0xff && bufferPos == 0) {
				engravingInProgress = false
				Platform.runLater[
					state = "Invalid position code!"
				]	
			}
			buffer.set(bufferPos, value)
			bufferPos = bufferPos + 1
			if(bufferPos == 5) {
				val x = buffer.get(1).intValue * 100 + buffer.get(2)
				val y = buffer.get(3).intValue * 100 + buffer.get(4)
				println('''X: «"%03d".format(x)» Y: «"%03d".format(y)»''')
//				println('''X: «"%03d".format(shortBuffer.get.swapBytes)» Y: «"%03d".format(shortBuffer.get.swapBytes)»''')
//				println(buffer.array.map["%02x".format(it)].join(" "))
				bufferPos = 0
			}
		}		
	}
	
	def short makeShort(byte upper, byte lower) {
		lower.bitwiseOr(upper.shortValue << 8).shortValue
	}
	
	def swapBytes(short value) {
		(value.bitwiseAnd(0xff00) >> 8).bitwiseOr(value.bitwiseAnd(0x00ff) << 8) as short
	}	
	
	def handshake() {
		sendCommand(NejeCommands.OPEN)
		
		val byte[] input = newByteArrayOfSize(2).map[portInputStream.read.byteValue]
		if(input.get(0) == 0x65 && input.get(1) == 0x6f) {
			setState("Ready.")
			setConnected(true)
		} else {
			setState("Handshake failed!")
		}
	}
	
	def void close() {
		if(getPort !== null) getPort.close
		setPort(null)
		setConnected(false)
		listenerTask?.cancel
	}
	
	def clearImage() {
		sendCommand(NejeCommands.CLEAR_IMAGE)
		
		setState("Clearing..")
		setIsWaiting(true)
		val waitTask = new Task<Void>() {
			override protected call() throws Exception {
				Thread.sleep(3000)
				Platform.runLater[
					setState("Ready.")
					setIsWaiting(false)
				]
				null
			}
		}
		new Thread(waitTask).start
		//Platform.runLater[println(port.inputStream.read.toHexString)]
	}
	
	def setSpeed(int speed) {
		if(1 <= speed && speed <= 240) {
			val byte[] command = newByteArrayOfSize(1)
			command.set(0, speed.byteValue)
			sendCommand(command)
		} else throw new IllegalArgumentException("Speed must be in the interval [1,240], but is " + speed)
	}
	
	def sendImage(RenderedImage image) {
		val ByteArrayOutputStream boss = new ByteArrayOutputStream(512*512/8)
		ImageIO.write(image, "bmp", boss)
		
		clearImage
		val waitForClearTask = new Task<Void>() {
			override protected call() throws Exception {
				while(isWaiting)
					Thread.sleep(10)
				Platform.runLater[
					val byte[] data = boss.toByteArray
					Files.write(Paths.get("/home", "may", "test.bmp"), data)
					println(data.length)
//					for(var pos=0; pos < data.length; pos+=4000) {
//						val array = {
//							if(data.length - pos >= 4000) {
//								Arrays.copyOfRange(data, pos, pos+4000)
//							} else {
//								Arrays.copyOfRange(data, pos, data.length)
//							}
//						}
//						println(port.writeBytes(array, array.length))
//						Thread.sleep(1000)
//					}
					port.outputStream.write(data)
					port.outputStream.flush
					
					setState("Sending..")
					setIsWaiting(true)
					val waitTask = new Task<Void>() {
						override protected call() throws Exception {
							Thread.sleep(1000)
							Platform.runLater[
								setState("Ready.")
								setIsWaiting(false)
							]
							null
						}
					}
					new Thread(waitTask).start
				]
				null
			}
		}
		new Thread(waitForClearTask).start
	}
	
	def startEngraving() {
		sendCommand(NejeCommands.START_ENGRAVING)
	}
	
	private def sendCommand(byte[] command) {
		port.outputStream.write(command)
		port.outputStream.flush
	}
	
	def toOrigin() {
		sendCommand(NejeCommands.MOVE_TO_ORIGIN)
	}
}
