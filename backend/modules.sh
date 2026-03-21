
go env -w GOPROXY=https://proxy.golang.org,direct
go env -w GOSUMDB=sum.golang.org
go get github.com/gin-gonic/gin@latest || true
go get github.com/gofiber/fiber/v2@latest || true
go get gofr.dev@latest || true
go get github.com/lib/pq@latest || true
go get github.com/joho/godotenv@latest || true
go get github.com/golang-jwt/jwt/v5@latest || true
go mod tidy
go mod verify