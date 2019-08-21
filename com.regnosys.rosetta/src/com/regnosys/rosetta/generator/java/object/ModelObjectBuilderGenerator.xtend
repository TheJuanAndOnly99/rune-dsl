package com.regnosys.rosetta.generator.java.object

import com.google.inject.Inject
import com.regnosys.rosetta.generator.object.ExpandedAttribute
import com.regnosys.rosetta.rosetta.RosettaClass
import com.regnosys.rosetta.rosetta.RosettaQualifiedType
import com.regnosys.rosetta.rosetta.RosettaRegularAttribute
import com.regnosys.rosetta.rosetta.RosettaType
import com.regnosys.rosetta.rosetta.impl.RosettaFactoryImpl
import com.regnosys.rosetta.rosetta.simple.Data
import com.rosetta.model.lib.RosettaModelObjectBuilder
import com.rosetta.util.BreadthFirstSearch
import java.util.Collection
import java.util.List
import java.util.Optional

import static extension com.regnosys.rosetta.generator.java.util.JavaClassTranslator.toJavaType
import static extension com.regnosys.rosetta.generator.util.RosettaAttributeExtensions.*
import org.eclipse.xtend2.lib.StringConcatenationClient
import com.rosetta.model.lib.meta.RosettaMetaData

class ModelObjectBuilderGenerator {
	
	@Inject extension ModelObjectBoilerPlate
	
	def builderName(RosettaType c) {
		return c.name + 'Builder';
	}
	
	def builderName(String typeName) {
		return typeName + 'Builder';
	}
	
	def builderSuperClass(RosettaClass clazz) {
		Optional.ofNullable(clazz.superType).map[builderName].orElse('RosettaModelObjectBuilder')
	}
	
	dispatch def StringConcatenationClient builderClass(Data c) '''
		public static class «builderName(c)» extends «RosettaModelObjectBuilder»{
		
			«FOR attribute : c.expandedAttributes»
				protected «attribute.toBuilderType» «attribute.name»;
			«ENDFOR»
		
			public «builderName(c)»() {
			}
					
			@Override
			public «RosettaMetaData»<? extends «c.name»> metaData() {
				return metaData;
			} 
		
			«c.expandedAttributes.builderGetters»
		
			«c.setters»
		
			public «c.name» build() {
				return new «c.name»(this);
			}
		
			@Override
			public «builderName(c)» prune() {
«««				«IF c.superType!==null»super.prune();«ENDIF»
				«FOR attribute : c.expandedAttributes»
					«IF !attribute.isMultiple && (attribute.type instanceof RosettaClass || attribute.hasMetas)»
						if («attribute.name»!=null && !«attribute.name».prune().hasData()) «attribute.name» = null;
					«ELSEIF attribute.isMultiple && attribute.type instanceof RosettaClass || attribute.hasMetas»
						if («attribute.name»!=null) «attribute.name» = «attribute.name».stream().filter(b->b!=null).map(b->b.prune()).filter(b->b.hasData()).collect(Collectors.toList());
					«ENDIF»
				«ENDFOR»
				return this;
			}
			
			«c.expandedAttributes.hasData(false)»
			
			«c.expandedAttributes.process(false)»
		
			«c.builderBoilerPlate»
		}
	'''
	
	dispatch def builderClass(RosettaClass c) '''
		public static «c.abstractModifier» class «builderName(c)» extends «c.builderSuperClass» «builderImplements(c)»{
		
			«FOR attribute : c.expandedAttributes»
				protected «attribute.toBuilderType» «attribute.name»;
			«ENDFOR»
		
			public «builderName(c)»() {
			}
					
			@Override
			public RosettaMetaData<? extends «c.name»> metaData() {
				return metaData;
			} 
		
			«c.expandedAttributes.builderGetters»
		
			«c.setters»
			««««ContractualProduct and event are the only objects that get qualified
			««««This could if necessary be replaced with code that finds all the quualifiaction rules
			««««and the qualification result fields and finds there common roots (current CP and EV)	
			«IF c.name=="ContractualProduct" || c.name=="Event"»
				«qualificationSetter(c)»
			«ENDIF»
			
			«IF !c.isAbstract»
				public «c.name» build() {
					return new «c.name»(this);
				}
			«ELSE»
				public abstract «c.name» build();
			«ENDIF»
		
			@Override
			public «builderName(c)» prune() {
				«IF c.superType!==null»super.prune();«ENDIF»
				«FOR attribute : c.expandedAttributes»
					«IF !attribute.isMultiple && (attribute.type instanceof RosettaClass || attribute.hasMetas)»
						if («attribute.name»!=null && !«attribute.name».prune().hasData()) «attribute.name» = null;
					«ELSEIF attribute.isMultiple && attribute.type instanceof RosettaClass || attribute.hasMetas»
						if («attribute.name»!=null) «attribute.name» = «attribute.name».stream().filter(b->b!=null).map(b->b.prune()).filter(b->b.hasData()).collect(Collectors.toList());
					«ENDIF»
				«ENDFOR»
				return this;
			}
			
			«c.expandedAttributes.hasData(c.superType!==null)»
			
			«c.expandedAttributes.process(c.superType!==null)»
		
			«c.builderBoilerPlate»
		}
	'''
	
	def builderImplements(RosettaClass c) {
		val implementsS = c.implementsClause[String s | '''«s.builderName»<«c.builderName»>''']
		
		
		if (c.name=="ContractualProduct" || c.name=="Event") {
			if (implementsS.length>0) '''«implementsS», Qualified'''
			else "implements Qualified"
		}
		else {
			implementsS
		}
	}
	
	def qualificationSetter(RosettaClass clazz) {
		val startAtt = RosettaFactoryImpl.eINSTANCE.createRosettaRegularAttribute
		startAtt.type = clazz
		val path = BreadthFirstSearch.search(startAtt, [att|att.getType.children], [att|att.type instanceof RosettaQualifiedType])
		if (path!==null) {
			'''
			public void setQualification(String qualification) {
				this«path.toSetter»
			}
			'''
		}
	}
	
	private def String toSetter(List<RosettaRegularAttribute> path) {
		val result = new StringBuilder
		for (var i=1;i<path.size-1;i++) {
			val att = path.get(i);
			result.append('''.getOrCreate«att.name.toFirstUpper»(«IF att.card.isIsMany»0«ENDIF»)''')
		}
		val last = path.last
		if (last.card.isIsMany) {
			result.append(".add"+last.name.toFirstUpper+"(qualification);")
		}
		else {
			result.append(".set"+last.name.toFirstUpper+"(qualification);")
		}
		result.toString()
	}

	private def process(List<ExpandedAttribute> attributes, boolean hasSuperType) '''
		@Override
		public void process(RosettaPath path, BuilderProcessor processor) {
			«IF hasSuperType»
				super.process(path, processor);
			«ENDIF»

			«FOR a : attributes.filter[!(isRosettaClass || hasMetas)]»
				processor.processBasic(path.newSubPath("«a.name»"), «a.toTypeSingle».class, «a.name», this);
			«ENDFOR»
			
			«FOR a : attributes.filter[isRosettaClass || hasMetas]»
				processRosetta(path.newSubPath("«a.name»"), processor, «a.toTypeSingle».class, «a.name»);
			«ENDFOR»
		}
	'''
	
	private def Collection<RosettaRegularAttribute> children(RosettaType c) {
		if (c instanceof RosettaClass) {
			c.regularAttributes
		}
		else {
			emptyList
		}
	}
	
	private def builderGetters(List<ExpandedAttribute> attributes) '''
		«FOR attribute : attributes»
			
			public «attribute.toBuilderType» get«attribute.name.toFirstUpper»() {
				return «attribute.name»;
			}
			
			«IF attribute.type instanceof RosettaClass || attribute.hasMetas»
				«IF !attribute.cardinalityIsListValue»
					public «attribute.toBuilderTypeSingle» getOrCreate«attribute.name.toFirstUpper»() {
						if («attribute.name»!=null) {
							return «attribute.name»;
						}
						else return «attribute.name» = new «attribute.toBuilderTypeSingle»();
					}
					
				«ELSE»
					public «attribute.toBuilderTypeSingle» getOrCreate«attribute.name.toFirstUpper»(int index) {
						if («attribute.name»==null) {
							this.«attribute.name» = new ArrayList<>();
						}
						return getIndex(«attribute.name», index, ()->new «attribute.toBuilderTypeSingle»());
					}
					
				«ENDIF»
			«ENDIF»
		«ENDFOR»
	'''
	
		
	private def setters(RosettaClass c) {
		var result = new StringBuilder(c.setters(c, false))
		var current = c.superType
		
		while (current !== null) {
			result.append(c.setters(current, true))
			current = current.superType
		}
		return result.toString
	}
		
	
	private def setters(Data thisClass) '''
		«FOR attribute : thisClass.expandedAttributes»
			«IF attribute.cardinalityIsListValue»
				public «thisClass.builderName» add«attribute.name.toFirstUpper»(«attribute.toTypeSingle» «attribute.name») {
					if(this.«attribute.name» == null){
						this.«attribute.name» = new ArrayList<>();
						this.«attribute.name».add(«attribute.toBuilder»);
					} else {
						this.«attribute.name».add(«attribute.toBuilder»);
					}
					return this;
				}

				«IF attribute.type instanceof RosettaClass»
					public «thisClass.builderName» add«attribute.name.toFirstUpper»Builder(«attribute.toBuilderTypeSingle» «attribute.name») {
						if(this.«attribute.name» == null){
							this.«attribute.name» = new ArrayList<>();
							this.«attribute.name».add(«attribute.name»);
						} else {
							this.«attribute.name».add(«attribute.name»);
						}
						return this;
					}
					
				«ENDIF»
				
				public «thisClass.builderName» clear«attribute.name.toFirstUpper»() {
					this.«attribute.name» = null;
					return this;
				}
			«ELSE»
				public «thisClass.builderName» set«attribute.name.toFirstUpper»(«attribute.toType» «attribute.name») {
					this.«attribute.name» = «attribute.toBuilder»;
					return this;
				}

				«IF attribute.type instanceof RosettaClass»
					public «thisClass.builderName» set«attribute.name.toFirstUpper»Builder(«attribute.toBuilderType» «attribute.name») {
						this.«attribute.name» = «attribute.name»;
						return this;
					}
					
				«ENDIF»
			«ENDIF»
		«ENDFOR»
	'''
	
	private def setters(RosettaClass thisClass, RosettaClass clazz, boolean isSuper) '''
		«FOR attribute : clazz.expandedAttributes»
			«IF attribute.cardinalityIsListValue»
				«IF isSuper»@Override «ENDIF»public «thisClass.builderName» add«attribute.name.toFirstUpper»(«attribute.toTypeSingle» «attribute.name») {
					if(this.«attribute.name» == null){
						this.«attribute.name» = new ArrayList<>();
						this.«attribute.name».add(«attribute.toBuilder»);
					} else {
						this.«attribute.name».add(«attribute.toBuilder»);
					}
					return this;
				}

				«IF attribute.type instanceof RosettaClass»
					«IF isSuper»@Override «ENDIF»public «thisClass.builderName» add«attribute.name.toFirstUpper»Builder(«attribute.toBuilderTypeSingle» «attribute.name») {
						if(this.«attribute.name» == null){
							this.«attribute.name» = new ArrayList<>();
							this.«attribute.name».add(«attribute.name»);
						} else {
							this.«attribute.name».add(«attribute.name»);
						}
						return this;
					}
					
				«ENDIF»
				
				«IF isSuper»@Override «ENDIF»public «thisClass.builderName» clear«attribute.name.toFirstUpper»() {
					this.«attribute.name» = null;
					return this;
				}
			«ELSE»
				«IF isSuper || clazz.globalKey && attribute.name === 'globalKey'»@Override «ENDIF»public «thisClass.builderName» set«attribute.name.toFirstUpper»(«attribute.toType» «attribute.name») {
					this.«attribute.name» = «attribute.toBuilder»;
					return this;
				}

				«IF attribute.type instanceof RosettaClass»
					«IF isSuper»@Override «ENDIF»public «thisClass.builderName» set«attribute.name.toFirstUpper»Builder(«attribute.toBuilderType» «attribute.name») {
						this.«attribute.name» = «attribute.name»;
						return this;
					}
					
				«ENDIF»
			«ENDIF»
		«ENDFOR»
	'''
	
	
	private def hasData(List<ExpandedAttribute> attributes, boolean hasSuperType) '''
		@Override
		public boolean hasData() {
			«IF hasSuperType»if (super.hasData()) return true;«ENDIF»
			«FOR attribute:attributes»    
				«IF attribute.cardinalityIsListValue»
					«IF attribute.type instanceof RosettaClass»
						if (get«attribute.name.toFirstUpper»()!=null && get«attribute.name.toFirstUpper»().stream().filter(Objects::nonNull).anyMatch(a->a.hasData())) return true;
					«ELSE»
						if (get«attribute.name.toFirstUpper»()!=null && !get«attribute.name.toFirstUpper»().isEmpty()) return true;
					«ENDIF»
				«ELSEIF attribute.type instanceof RosettaClass»
					if (get«attribute.name.toFirstUpper»()!=null && get«attribute.name.toFirstUpper»().hasData()) return true;
				«ELSE»
					if (get«attribute.name.toFirstUpper»()!=null) return true;
				«ENDIF»
			«ENDFOR»
			return false;
		}
	'''

	
	private def abstractModifier(RosettaClass clazz) '''
		«IF clazz.isAbstract»abstract«ENDIF»
	'''
	
	
	private def toBuilderType(ExpandedAttribute attribute) {
		if (attribute.isMultiple) '''List<«attribute.toBuilderTypeSingle»>'''
		else attribute.toBuilderTypeSingle;
	}
	
	private def toBuilderTypeSingle(ExpandedAttribute attribute) {
		if (attribute.hasMetas) {
			if (attribute.refIndex>=0) {
				if (attribute.type instanceof RosettaClass)
					'''ReferenceWithMeta«attribute.typeName.toFirstUpper».ReferenceWithMeta«attribute.typeName.toFirstUpper»Builder'''
				else
					'''BasicReferenceWithMeta«attribute.typeName.toFirstUpper».BasicReferenceWithMeta«attribute.typeName.toFirstUpper»Builder'''
			}
			else {
				'''FieldWithMeta«attribute.typeName.toFirstUpper».FieldWithMeta«attribute.typeName.toFirstUpper»Builder'''
			}
		}
		else  {
			attribute.toBuilderTypeUnderlying
		}
	}
	
	private def toBuilderTypeUnderlying(ExpandedAttribute attribute) {
		if (attribute.type instanceof RosettaClass) '''«attribute.typeName».«attribute.typeName»Builder'''
		else attribute.typeName.toJavaType
	}
	
		
	private def toBuilder(ExpandedAttribute attribute) {
		if(attribute.type instanceof RosettaClass || attribute.hasMetas) {
			'''«attribute.name».toBuilder()'''
		} else {
			attribute.name
		}
	}	
}