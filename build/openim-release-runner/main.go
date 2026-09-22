package main

import (
	"errors"
	"flag"
	"log"
	"os"

	"github.com/openimsdk/gomake/mageutil"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("usage: openim-release-runner build|start [service ...]")
	}

	switch args[0] {
	case "build":
		if len(args) != 1 {
			return errors.New("build does not accept service arguments")
		}
		// 复用已锁定 gomake 的目录发现和发布编译逻辑，保证与原 Mage 目标一致。
		mageutil.Build(nil, nil, nil)
		return nil
	case "start":
		// 启动前读取构建生成的服务清单，并保持原 Mage 启动器的文件描述符上限。
		mageutil.InitForSSC()
		if err := setMaxOpenFiles(); err != nil {
			return err
		}
		flag.CommandLine = flag.NewFlagSet("openim-release-runner", flag.ContinueOnError)
		if err := flag.CommandLine.Parse(args[1:]); err != nil {
			return err
		}
		mageutil.StartToolsAndServices(flag.Args(), nil)
		return nil
	default:
		return errors.New("usage: openim-release-runner build|start [service ...]")
	}
}
