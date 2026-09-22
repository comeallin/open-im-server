package controller

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"github.com/openimsdk/open-im-server/v3/pkg/common/config"
	"github.com/openimsdk/tools/tokenverify"
)

func TestCreateTokenUsesConfiguredSecondTTL(t *testing.T) {
	const tokenTTL = 15 * time.Minute
	authDatabase := NewAuthDatabase(nil, "test-signing-key", tokenTTL, config.MultiLogin{}, []string{"admin-user"})

	token, err := authDatabase.CreateToken(t.Context(), "admin-user", 5)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := jwt.ParseWithClaims(token, &tokenverify.Claims{}, func(*jwt.Token) (any, error) {
		return []byte("test-signing-key"), nil
	})
	if err != nil || !parsed.Valid {
		t.Fatalf("签发的令牌无法验证: %v", err)
	}
	claims, ok := parsed.Claims.(*tokenverify.Claims)
	if !ok || claims.ExpiresAt == nil || claims.IssuedAt == nil {
		t.Fatal("签发的令牌缺少标准时间声明")
	}
	if lifetime := claims.ExpiresAt.Time.Sub(claims.IssuedAt.Time); lifetime < tokenTTL || lifetime > tokenTTL+10*time.Second {
		t.Fatalf("令牌有效期=%s，期望约为%s", lifetime, tokenTTL)
	}
}
