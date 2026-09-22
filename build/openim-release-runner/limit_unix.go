//go:build !windows

package main

import (
	"fmt"
	"syscall"

	"github.com/openimsdk/gomake/mageutil"
)

func setMaxOpenFiles() error {
	var limit syscall.Rlimit
	if err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &limit); err != nil {
		return fmt.Errorf("get file descriptor limit: %w", err)
	}
	limit.Max = uint64(mageutil.MaxFileDescriptors)
	limit.Cur = uint64(mageutil.MaxFileDescriptors)
	if err := syscall.Setrlimit(syscall.RLIMIT_NOFILE, &limit); err != nil {
		return fmt.Errorf("set file descriptor limit: %w", err)
	}
	return nil
}
