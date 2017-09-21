package de.mayjs.extensions

import javafx.beans.binding.Bindings
import javafx.beans.value.ObservableBooleanValue

class BooleanBindingExtensions {
	static def !(ObservableBooleanValue value){
		Bindings.not(value)	
	}
	
	static def &&(ObservableBooleanValue a, ObservableBooleanValue b) {
		Bindings.and(a, b)
	}
}