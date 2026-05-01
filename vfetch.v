import os

const bold = "\e[1m"
const reset = "\e[0m"
const yellow = "\e[33m"
const cyan = "\e[36m"

fn os_name() string {
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
}

fn kernel() string {
	txt := os.read_file('/proc/version') or { return 'Unknown' }
	parts := txt.split(' ')
	if parts.len >= 3 {
		return parts[2]
	}
	return 'Unknown'
}

fn uptime() string {
	txt := os.read_file('/proc/uptime') or { return 'Unknown' }
	secs := int(txt.split(' ')[0].f64())
	days := secs / 86400
	mut res := ""
	if days > 0 {
		// 注意这里：强制加上大括号 ${days}，治好 0.5.1 的插值瞎眼病
		res += "${days} days, "
	}
	res += "${(secs % 86400) / 3600} hours, ${(secs % 3600) / 60} mins"
	return res
}

fn shell_name() string {
	sh := os.getenv('SHELL')
	if sh != '' {
		parts := sh.split('/')
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
	return 'Unknown'
}

fn cpu() string {
	txt := os.read_file('/proc/cpuinfo') or { return 'Unknown' }
	for line in txt.split('\n') {
		if line.starts_with('model name') {
			parts := line.split(':')
			if parts.len > 1 {
				return parts[1].trim_space()
			}
		}
	}
	return 'Unknown'
}

fn mem() string {
	txt := os.read_file('/proc/meminfo') or { return 'Unknown' }
	mut total := 0
	mut avail := 0
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
