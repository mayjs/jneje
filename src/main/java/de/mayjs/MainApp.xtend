package de.mayjs

import javafx.fxml.FXMLLoader
import javafx.scene.Parent
import javafx.scene.Scene
import javafx.stage.Stage
import xtendfx.FXApp

@FXApp
class MainApp {
	override void start(Stage it) throws Exception {
		var Parent root = FXMLLoader::load(MainApp.getResource("/fxml/Scene.fxml"))
		var Scene sscene = new Scene(root)
		sscene.stylesheets += "/styles/Styles.css"
		
		title = "JNeje"
		scene = sscene
		show
	}
}
