set(CASE_NAME cwhip_rejects_string_slice_method)
set(CASE_FIXTURE negative_string_slice_method.cw)
set(CASE_EXPECTED_DIAGNOSTIC [==[class 'String' has no method 'slice']==])
