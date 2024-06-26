/*
 * Copyright 2024 REGnosys
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.rosetta.model.lib.validation;

import java.util.List;

import com.google.common.collect.Lists;
import com.rosetta.model.lib.RosettaModelObject;
import com.rosetta.model.lib.path.RosettaPath;

public interface Validator<T extends RosettaModelObject> {

	@Deprecated // Since 9.7.0: use `getValidationResults` instead.
	ValidationResult<T> validate(RosettaPath path, T objectToBeValidated);
	
	default List<ValidationResult<?>> getValidationResults(RosettaPath path, T objectToBeValidated) {
		return Lists.newArrayList(validate(path, objectToBeValidated)); // @Compat: for backwards compatibility. Old generated code will not have an implementation for this method.
	}
}