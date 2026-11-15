test_harness = find_program('./edid-decode-check.sh', native: true)

di_print = executable(
	'di-print',
	'di-print.c',
	dependencies: di_dep,
	install: false,
)

print_harness = find_program('./di-print-check.sh', native: true)

test_env = [
	'DI_EDID_DECODE=' + di_edid_decode.full_path(),
	'DI_PRINT=' + di_print.full_path(),
]

edid_test_cases = [
	'acer-p1276',
	'amazon-fire-tv-48',
	'apple-xdr-dp',
	'asus-ux3405',
	'ayaneo-wxga',
	'cta-timings',
	'cta-timings',
	'cta-vfpdb',
	'custom-uncommon-cta-vesa',
	'cvt',
	'dell-2408wfp-dp',
	'goldstar-37lg5000',
	'goldstar-e2441',
	'goldstar-ite6604-hdmi',
	'hisense-55u8k',
	'hitachi-55r6+',
	'hp-5dq99aa-hdmi',
	'jdi-lpm135m467-edp',
	'lenovo-t24s28',
	'lenovo-t27p10',
	'msi-mag321curv-dp',
	'panasonic-mei96a2-dp',
	'philips-4k-2023',
	'philips-ftv-2017',
	'philips-ftv-490',
	'qemu',
	'samsung-odyssey-g60sd',
	'samsung-q800t-hdmi2.0',
	'samsung-qn900b-8k',
	'samsung-s27a950d-dp',
	'sun-gh19ps-dvi',
	'tcl-smart-tv-5655',
	'viewsonic-vp2768-dp',
	'vizio-d40fj09',
]

displayid_test_cases = [
	'apple-studio-xdr',
]

di_print_test_cases = []
foreach tc : edid_test_cases
	di_print_test_cases += [tc + '.edid']
endforeach
foreach tc : displayid_test_cases
	di_print_test_cases += [tc + '.displayid']
endforeach

foreach tc : edid_test_cases
	test(
		'decode-' + tc,
		test_harness,
		args: [files('data/' + tc + '.edid')],
		env: test_env,
		depends: [di_edid_decode],
	)
endforeach

# The print tests expect manufacturer names.
foreach tc : pnp_ids.length() > 0 ? di_print_test_cases : []
	test(
		'print-' + tc,
		print_harness,
		args: [files('data/' + tc)],
		env: test_env,
		depends: [di_print],
	)
endforeach

edid_decode_gen_cmd = find_program('./edid-decode-gen.sh', native: true)
di_print_gen_cmd = find_program('./di-print-gen.sh', native: true)

edid_gen_targets = []
foreach tc : edid_test_cases
	edid_gen_targets += files('data/' + tc + '.edid')
endforeach

displayid_gen_targets = []
foreach tc : displayid_test_cases
	displayid_gen_targets += files('data/' + tc + '.displayid')
endforeach

gen_targets = edid_gen_targets + displayid_gen_targets

subproject(
	'v4l-utils',
	required: false,
	default_options: [
		'bpf=disabled',
		'gconv=disabled',
		'jpeg=disabled',
		'libdvbv5=disabled',
		'qv4l2=disabled',
		'qvidcap=disabled',
		'v4l2-tracer=disabled',
		'v4l-plugins=false',
		'v4l-wrappers=false',
		'doxygen-doc=disabled',
	],
)
ref_edid_decode = find_program('edid-decode', native: true, required: false)
if ref_edid_decode.found()
	test_env += 'REF_EDID_DECODE=' + ref_edid_decode.full_path()

	edid_decode_gen = run_target(
		'gen-test-data-edid-decode',
		command: [edid_decode_gen_cmd] + edid_gen_targets,
		depends: [di_edid_decode],
		env: test_env,
	)

	gen_test_data = [edid_decode_gen]
	if pnp_ids.length() > 0
		di_print_gen = run_target(
			'gen-test-data-di-print',
			command: [di_print_gen_cmd] + gen_targets,
			depends: [di_print],
			env: test_env,
		)
		gen_test_data += di_print_gen
	endif

	alias_target('gen-test-data', gen_test_data)
endif
