package com.regnosys.rosetta.generator.java.calculation

import com.google.inject.Inject
import com.regnosys.rosetta.generator.java.util.JavaNames
import com.regnosys.rosetta.rosetta.RosettaModel
import com.regnosys.rosetta.tests.util.ModelHelper
import java.util.function.Consumer
import org.eclipse.xtext.xbase.testing.RegisteringFileSystemAccess

import static org.junit.jupiter.api.Assertions.*

class CalculationGeneratorHelper {

	@Inject CalculationGenerator generator
	@Inject extension ModelHelper
	@Inject RegisteringFileSystemAccess fsa
	@Inject JavaNames.Factory factory

	def void assertToGeneratedFunction(CharSequence actualModel, CharSequence expected) throws AssertionError {
		actualModel.assertToGenerated(expected, [
			generator.generateFunctions(fsa, it.elements, factory.create(it), "test")
		])
	}

	def void assertToGeneratedCalculation(CharSequence actualModel, CharSequence expected) throws AssertionError {
		actualModel.assertToGenerated(expected, [
			generator.generateCalculation(fsa, it.elements, factory.create(it), "test")
		])
	}

	def protected void assertToGenerated(CharSequence actualModel, CharSequence expected,
		Consumer<RosettaModel> genCall) throws AssertionError {
		val model = actualModel.parseRosettaWithNoErrors
		genCall.accept(model)
		assertEquals(expected.toString, fsa.textFiles.entrySet.head.value)
	}
}
