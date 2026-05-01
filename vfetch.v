import os

const bold = "\e[1m"
const reset = "\e[0m"
const yellow = "\e[33m"
const cyan = "\e[36m"

fn run_cmd(cmd string) string {
	res := os.execute(cmd)
	if res.exit_code == 0 {
		return res.output.trim_space()
	}
	return ''
}

fn get_os_type() string {
	sys := os.uname().sysname
	if sys == 'Linux' {
		return 'Linux'
	} else if sys == 'Darwin' {
		return 'Mac'
	} else if sys.starts_with('MINGW') || sys.starts_with('MSYS') || sys == 'Windows' {
		return 'Windows'
	}
	return 'Unknown'
}

fn os_name() string {
	os_type := get_os_type()
	if os_type == 'Linux' {
		txt := os.read_file('/etc/os-release') or { return 'Unknown' }
		for line in txt.split('\n') {
			if line.starts_with('PRETTY_NAME=') {
				parts := line.split('=')
				if parts.len > 1 {
					return parts[1].trim('"')
				}
			}
		}
		return 'Unknown'
	} else if os_type == 'Mac' {
		name := run_cmd('sw_vers -productName')
		ver := run_cmd('sw_vers -productVersion')
		if name != '' && ver != '' {
			return '$name $ver'
		}
	} else if os_type == 'Windows' {
		name := run_cmd('wmic os get caption')
		if name != '' {
			parts := name.split('\n')
			if parts.len > 1 {
				return parts[1].trim_space()
			}
		}
	}
	return 'Unknown'
}

fn kernel() string {
	os_type := get_os_type()
	if os_type == 'Linux' {
		txt := os.read_file('/proc/version') or { return 'Unknown' }
		parts := txt.split(' ')
		if parts.len >= 3 {
			return parts[2]
		}
	} else if os_type == 'Mac' {
		return 'Darwin ' + run_cmd('uname -r')
	} else if os_type == 'Windows' {
		ver := run_cmd('ver')
		if ver != '' {
			return ver.all_after('[').trim('[]')
		}
	}
	return 'Unknown'
}

fn uptime() string {
	os_type := get_os_type()
	mut secs := 0
	
	if os_type == 'Linux' {
		txt := os.read_file('/proc/uptime') or { return 'Unknown' }
		secs = int(txt.split(' ')[0].f64())
	} else if os_type == 'Mac' {
		out := run_cmd('uptime')
		mut up_str := out.all_after('up ')
		if up_str.contains(',') {
			up_str = up_str.all_before(',')
		}
		return up_str.trim_space()
	} else if os_type == 'Windows' {
		out := run_cmd('powershell -c "(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | % { \'{0} days, {1} hours, {2} mins\' -f $_.Days, $_.Hours, $_.Minutes }"')
		if out != '' {
			return out
		}
	}

	if os_type == 'Linux' || os_type == 'Windows' {
		days := secs / 86400
		mut res := ""
		if days > 0 {
			res += "$days days, "
		}
		res += "${(secs % 86400) / 3600} hours, ${(secs % 3600) / 60} mins"
		return res
	}

	return 'Unknown'
}

fn shell_name() string {
	sh := os.getenv('SHELL')
	if sh != '' {
		parts := sh.split('/')
		return parts[parts.len - 1]
	}
	sh_win := os.getenv('COMSPEC')
	if sh_win != '' {
		parts := sh_win.split('\\')
		return parts[parts.len - 1]
	}
	return 'Unknown'
}

fn term_name() string {
	t := os.getenv('TERM_PROGRAM')
	if t != '' {
		return t
	}
	t2 := os.getenv('TERM')
	if t2 != '' {
		return t2
	}
	t_win := os.getenv('WT_SESSION')
	if t_win != '' {
		return 'Windows Terminal'
	}
	return 'Unknown'
}

fn cpu() string {
	os_type := get_os_type()
	if os_type == 'Linux' {
		txt := os.read_file('/proc/cpuinfo') or { return 'Unknown' }
		for line in txt.split('\n') {
			if line.starts_with('model name') {
				parts := line.split(':')
				if parts.len > 1 {
					return parts[1].trim_space()
				}
			}
		}
	} else if os_type == 'Mac' {
		return run_cmd('sysctl -n machdep.cpu.brand_string')
	} else if os_type == 'Windows' {
		out := run_cmd('wmic cpu get name')
		if out != '' {
			lines := out.split('\n')
			if lines.len > 1 {
				return lines[1].trim_space()
			}
		}
	}
	return 'Unknown'
}

fn mem() string {
	os_type := get_os_type()
	mut total := 0
	mut avail := 0

	if os_type == 'Linux' {
		txt := os.read_file('/proc/meminfo') or { return 'Unknown' }
		for line in txt.split('\n') {
			if line.starts_with('MemTotal:') {
				val := line.all_after(':').trim_space().split(' ')[0]
				if val != '' {
					total = val.int()
				}
			} else if line.starts_with('MemAvailable:') {
				val := line.all_after(':').trim_space().split(' ')[0]
				if val != '' {
					avail = val.int()
				}
			}
		}
		return "${(total - avail) / 1024} MiB / ${total / 1024} MiB"
	} else if os_type == 'Mac' {
		total_str := run_cmd('sysctl -n hw.memsize')
		if total_str != '' {
			total = total_str.int() / 1024 / 1024
		}
		used_str := run_cmd("ps -c -o rss= -A | awk '{sum+=\$1} END {print sum/1024}'")
		if used_str != '' {
           return "${used_str.split('.')[0].int()} MiB / $total MiB"
		}
		return "N/A / $total MiB"
	} else if os_type == 'Windows' {
		out := run_cmd('wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /Value')
		for line in out.split('\n') {
			if line.starts_with('TotalVisibleMemorySize=') {
				total = line.all_after('=').trim_space().int() / 1024
			} else if line.starts_with('FreePhysicalMemory=') {
				avail = line.all_after('=').trim_space().int() / 1024
			}
		}
		if total > 0 {
			return "${total - avail} MiB / $total MiB"
		}
	}
	return 'Unknown'
}

fn get_v_ver() string {
	res := os.execute('v version')
	if res.exit_code == 0 {
		return res.output.trim_space()
	}
	return 'Not installed'
}

fn main() {
	logo := "${yellow}__      __\n\\ \\    / /\n \\ \\  / / \n  \\ \\/ /  \n   \\  /   \n    \\/    \n${reset}"

	host := os.hostname() or { 'Unknown' }

	println(logo)
	println("${bold}${yellow}${host}@vfetch${reset}")
	println("  ───────────────────────────────")

	info := [
		['OS', os_name()],
		['Host', host],
		['Kernel', kernel()],
		['Uptime', uptime()],
		['Shell', shell_name()],
		['Terminal', term_name()],
		['CPU', cpu()],
		['Memory', mem()],
	]

	for item in info {
		println("${bold}${item[0]}${reset}: ${bold}${cyan}${item[1]}${reset}")
	}

	println("")
	println("${bold}V Environment${reset}")
	println("  ───────────────────────────────")

	u := os.uname()
	v_info := [
		['Version', get_v_ver()],
		['OS', u.sysname],
		['Arch', u.machine],
	]

	for item in v_info {
		println("${bold}${item[0]}${reset}: ${bold}${cyan}${item[1]}${reset}")
	}

	println("")
	println("${yellow}███${cyan}███${reset}")
}
