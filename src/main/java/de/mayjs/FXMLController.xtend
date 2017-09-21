package de.mayjs

import de.mayjs.neje.NejeConnection
import java.awt.Color
import java.awt.image.BufferedImage
import java.net.URL
import java.util.Collection
import java.util.Enumeration
import java.util.Iterator
import java.util.List
import java.util.ResourceBundle
import javafx.beans.binding.Bindings
import javafx.fxml.FXML
import javafx.fxml.Initializable
import javafx.scene.control.Button
import javafx.scene.control.ComboBox
import javafx.scene.control.Label
import javafx.util.StringConverter
import purejavacomm.CommPortIdentifier

import static extension de.mayjs.extensions.BooleanBindingExtensions.*
import static extension xtendfx.beans.binding.BindingExtensions.*
import javafx.scene.control.Slider
import javafx.beans.value.ChangeListener
import javafx.beans.value.ObservableValue
import de.mayjs.neje.NewNejeConnection

class FXMLController implements Initializable {
	@FXML ComboBox<CommPortIdentifier> serialPortList
	@FXML Button refreshSerialBtn
	@FXML Button connectBtn
	@FXML Button clearBtn
	@FXML Button sendImageBtn
	@FXML Button startBtn
	@FXML Button toOriginBtn
	@FXML Label statusLabel
	@FXML Label speedLabel
	@FXML Slider speedSlider
	

	var NejeConnection connection = new NejeConnection

	override void initialize(URL url, ResourceBundle rb) {
		serialPortList.converter = new StringConverter<CommPortIdentifier>() {
			override fromString(String string) {
				throw new UnsupportedOperationException("Can't do!")
			}
			
			override toString(CommPortIdentifier it) {
				'''«name»'''
			}
		}
		
		
		refreshSerialBtn.onAction = [refreshPorts]
		refreshPorts
		
		connectBtn.textProperty -> Bindings.when(connection.connectedProperty).then("Disconnect").otherwise("Connect")
		connectBtn.onAction = [ e |
			new NewNejeConnection().open(serialPortList.selectionModel.selectedItem)
//			if(!connection.connected)
//				connection.open(serialPortList.selectionModel.selectedItem)
//			else
//				connection.close
		]
		
		sendImageBtn.onAction = [
//			val image = ImageIO.read(new File("/home/may/test.bmp"))
//			println(image.colorModel)
			val image = new BufferedImage(512, 512, BufferedImage.TYPE_BYTE_BINARY)
			val graphics = image.createGraphics
			graphics.color = Color.WHITE
			graphics.fillRect(0,0,512,512)
			graphics.color = Color.BLACK;
			(1..3).forEach[graphics.drawLine(30,30+it,240,30+it)]
			
			connection.sendImage(image)
		]
		
		startBtn.onAction = [
			connection.startEngraving()
		]
		
		toOriginBtn.onAction = [
			connection.toOrigin()
		]
		
		speedLabel.textProperty -> Bindings.format("%03.0f", speedSlider.valueProperty)
		speedSlider.valueChangingProperty.addListener(new ChangeListener<Boolean>() {
			override changed(ObservableValue<? extends Boolean> observable, Boolean oldValue, Boolean newValue) {
				if(!newValue) {
					connection.speed = speedSlider.value as int
				}
			}
		})
		
		clearBtn.onAction = [connection.clearImage]
		
		statusLabel.textProperty -> connection.stateProperty
		
		#[clearBtn, sendImageBtn, startBtn, toOriginBtn, speedSlider].forEach[
			disableProperty -> !(connection.connectedProperty && !connection.isWaitingProperty)
		]
		
		
	}
	
	private def refreshPorts(){
		serialPortList.items <= CommPortIdentifier.portIdentifiers.cheapIterable
		if(!serialPortList.items.empty)
			serialPortList.selectionModel.select(0)
	}
	
	private static def <T> void <=(Collection<T> it, Iterable<T> newElements) {
		clear
		it += newElements
	}
	
	private static def <T> Iterable<T> cheapIterable(Enumeration<T> e) {
		return new Iterable<T>() {			
			override iterator() {
				return new Iterator<T>(){
					override hasNext() {
						e.hasMoreElements
					}
					
					override next() {
						e.nextElement
					}
				}
			}
		}
	}
	
	private static def <T> List<T> toList(Enumeration<T> e) {
		val result = <T>newLinkedList()
		while(e.hasMoreElements)
			result.addLast(e.nextElement)
		result
	}
}
