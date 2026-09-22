package config

import (
	"testing"
	"time"
)

func TestTokenPolicyDurationPrefersSeconds(t *testing.T) {
	duration, err := (TokenPolicy{Expire: 90, ExpireSeconds: 900}).Duration()
	if err != nil {
		t.Fatal(err)
	}
	if duration != 15*time.Minute {
		t.Fatalf("秒级有效期=%s，期望15分钟", duration)
	}
}

func TestTokenPolicyDurationFallsBackToLegacyDays(t *testing.T) {
	duration, err := (TokenPolicy{Expire: 2}).Duration()
	if err != nil {
		t.Fatal(err)
	}
	if duration != 48*time.Hour {
		t.Fatalf("兼容天级有效期=%s，期望48小时", duration)
	}
}

func TestTokenPolicyDurationRejectsMissingValues(t *testing.T) {
	if _, err := (TokenPolicy{}).Duration(); err == nil {
		t.Fatal("缺少有效期配置仍被接受")
	}
}
