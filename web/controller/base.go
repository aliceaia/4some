package controller

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"x-ui/web/session"
)

type BaseController struct {
}

func (a *BaseController) checkLogin(c *gin.Context) {
	if !session.IsLogin(c) {
		if isAjax(c) {
			pureJsonMsg(c, false, "Đã hết thời hạn đăng nhập, vui lòng đăng nhập lại")
		} else {
			c.Redirect(http.StatusTemporaryRedirect, c.GetString("base_path"))
		}
		c.Abort()
	} else {
		c.Next()
	}
}
