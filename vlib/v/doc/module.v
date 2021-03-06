module doc

import v.table
import v.parser
import v.ast
import os

// get_parent_mod - return the parent mod name, in dot format.
// It works by climbing up the folder hierarchy, until a folder,
// that either contains main .v files, or a v.mod file is reached.
// For example, given something like /languages/v/vlib/x/websocket/tests/autobahn
// it returns `x.websocket.tests`, because /languages/v/ has v.mod file in it.
// NB: calling this is expensive, so keep the result, instead of recomputing it.
fn get_parent_mod(input_dir string) ?string {
	$if windows {
		// windows root path is C: or D:
		if input_dir.len <= 2 {
			return error('root folder reached')
		}
	} $else {
		if input_dir.len == 0 {
			return error('root folder reached')
		}
	}
	base_dir := os.dir(input_dir)
	input_dir_name := os.file_name(base_dir)
	prefs := new_vdoc_preferences()
	fentries := os.ls(base_dir) or {
		[]string{}
	}
	files := fentries.filter(!os.is_dir(it))
	if 'v.mod' in files {
		// the top level is reached, no point in climbing up further
		return ''
	}
	v_files := prefs.should_compile_filtered_files(base_dir, files)
	if v_files.len == 0 {
		parent_mod := get_parent_mod(base_dir) or {
			return input_dir_name
		}
		if parent_mod.len > 0 {
			return parent_mod + '.' + input_dir_name
		}
		return error('No V files found.')
	}
	tbl := table.new_table()
	scope := &ast.Scope{
		parent: 0
	}
	file_ast := parser.parse_file(v_files[0], tbl, .skip_comments, prefs, scope)
	if file_ast.mod.name == 'main' {
		return ''
	}
	parent_mod := get_parent_mod(base_dir) or {
		return input_dir_name
	}
	if parent_mod.len > 0 {
		return '${parent_mod}.$file_ast.mod.name'
	}
	return file_ast.mod.name
}

pub fn lookup_module_with_path(mod string, base_path string) ?string {
	mod_path := mod.replace('.', os.path_separator)
	compile_dir := os.real_path(base_path)
	modules_dir := os.join_path(compile_dir, 'modules', mod_path)
	vlib_path := os.join_path(os.dir(@VEXE), 'vlib', mod_path)
	vmodules_path := os.join_path(os.home_dir(), '.vmodules', mod_path)
	paths := [modules_dir, vlib_path, vmodules_path]
	for path in paths {
		if !os.exists(path) || os.is_dir_empty(path) {
			continue
		}
		return path
	}
	return error('module "$mod" not found.')
}

pub fn lookup_module(mod string) ?string {
	return lookup_module_with_path(mod, os.dir('.'))
}

pub fn generate_from_mod(module_name string, pub_only bool, with_comments bool) ?Doc {
	mod_path := lookup_module(module_name) ?
	return generate(mod_path, pub_only, with_comments)
}
