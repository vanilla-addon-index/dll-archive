project(
	'libdisplay-info',
	'c',
	version: '0.5.0-dev',
	license: 'MIT',
	meson_version: '>= 0.60.0',
	default_options: [
		'c_std=c11',
		'warning_level=3',
		'wrap_mode=nodownload',
	],
)

version = meson.project_version().split('-')[0]
version_major = version.split('.')[0]
version_minor = version.split('.')[1]
assert(version_major == '0')

pnp_ids = []
if get_option('pnp-ids').allowed()
	dep_hwdata = dependency('hwdata', required: false, native: true)
	if dep_hwdata.found()
		hwdata_dir = dep_hwdata.get_variable(pkgconfig: 'pkgdatadir')
		pnp_ids = files(hwdata_dir / 'pnp.ids')
	elif import('fs').is_file('/usr/share/hwdata/pnp.ids')
		pnp_ids = files('/usr/share/hwdata/pnp.ids')
	elif get_option('pnp-ids').enabled()
		error('pnp.ids not found, install hwdata or set -Dpnp-ids=disabled')
	endif
endif

gen_search_table = find_program('tool/gen-search-table.py')
pnp_id_table = custom_target(
	'pnp-id-table.c',
	command: [ gen_search_table, pnp_ids, '@OUTPUT@', 'pnp_id_table' ],
	output: 'pnp-id-table.c',
)

cc = meson.get_compiler('c')

math = cc.find_library('m', required: false)

add_project_arguments(['-D_POSIX_C_SOURCE=200809L'], language: 'c')

# MSVC doesn't support static in array parameters.
if cc.compiles('void f(int a[static 1]);', name: 'static array parameters')
	add_project_arguments(['-Dstatic_array=static'], language: 'c')
else
	add_project_arguments(['-Dstatic_array='], language: 'c')
endif

if not cc.has_type('ssize_t', prefix: '#include <sys/types.h>')
	add_project_arguments(['-Dssize_t=ptrdiff_t'], language: 'c')
endif

add_project_arguments(cc.get_supported_arguments([
	'-Wundef',
	'-Wmissing-prototypes',
	'-Walloca',
	'-Wdeclaration-after-statement',
	'-Wconversion',

	'-Wno-unused-parameter',
	'-Wno-missing-field-initializers',

	'-Werror=implicit',
]), language: 'c')

# Same as -Wno-unused-parameter.
if cc.get_argument_syntax() == 'msvc'
	add_project_arguments(['/wd4100'], language: 'c')
endif

symbols_file = 'libdisplay-info.map'
symbols_flag = '-Wl,--version-script,@0@'.format(meson.current_source_dir() / symbols_file)
link_args = cc.has_link_argument(symbols_flag) ? [symbols_flag] : []
if cc.get_argument_syntax() == 'msvc' and get_option('default_library') != 'static'
	error('MSVC builds have no export list, use -Ddefault_library=static')
endif

di_lib = library(
	'display-info',
	[
		'cta.c',
		'cvt.c',
		'displayid.c',
		'displayid2.c',
		'dmt.c',
		'dmt-table.c',
		'edid.c',
		'gtf.c',
		'info.c',
		'log.c',
		'memory-stream.c',
		'cta-vic.c',
		'cta-vic-table.c',
		'hdmi-vic.c',
		pnp_id_table,
	],
	include_directories: include_directories('include'),
	dependencies: [math],
	link_args: link_args,
	link_depends: symbols_file,
	install: true,
	version: version,
	soversion: version_minor,
)

install_subdir(
	'include/libdisplay-info',
	install_dir: get_option('includedir'),
)

pkgconfig = import('pkgconfig')
pkgconfig.generate(
	di_lib,
	filebase: 'libdisplay-info',
	name: 'libdisplay-info',
	url: 'https://gitlab.freedesktop.org/emersion/libdisplay-info',
	description: 'EDID and DisplayID library',
)

di_dep = declare_dependency(
	link_with: di_lib,
	include_directories: include_directories('include'),
)

meson.override_dependency('libdisplay-info', di_dep)

# di-edid-decode needs getopt. test/ uses it, so it's skipped too.
build_tools = get_option('tools').require(
	cc.has_header('getopt.h'),
	error_message: 'di-edid-decode needs getopt.h',
).allowed()
if build_tools
	subdir('di-edid-decode')
	subdir('test')
endif
