import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { UserDTO, UserRole } from '@/types/api'
import { login as loginApi, logout as logoutApi, getMe } from '@/api/auth'
import {
  setToken,
  getToken,
  getRefreshToken,
  clearTokens,
} from '@/api/request'

export const useUserStore = defineStore('user', () => {
  const user = ref<UserDTO | null>(null)
  const token = ref<string | null>(getToken())

  const isLoggedIn = computed(() => !!token.value)
  const role = computed<UserRole | null>(() => user.value?.role ?? null)

  const isAdmin = computed(() => role.value === 'ADMIN')
  const isEditor = computed(() => role.value === 'EDITOR' || role.value === 'ADMIN')

  async function login(username: string, password: string) {
    const { data: res } = await loginApi({ username, password })
    token.value = res.accessToken
    setToken(res.accessToken)
    localStorage.setItem('refresh_token', res.refreshToken)
    await fetchUser()
  }

  async function fetchUser() {
    const { data: res } = await getMe()
    user.value = res.data
  }

  async function logout() {
    try {
      await logoutApi(getRefreshToken())
    } finally {
      token.value = null
      user.value = null
      clearTokens()
    }
  }

  async function init() {
    if (!token.value) return
    try {
      await fetchUser()
    } catch {
      // token 无效，清除
      token.value = null
      user.value = null
      clearTokens()
    }
  }

  return {
    user,
    token,
    isLoggedIn,
    role,
    isAdmin,
    isEditor,
    login,
    logout,
    fetchUser,
    init,
  }
})
