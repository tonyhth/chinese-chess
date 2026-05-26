import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import { useUserStore } from '@/stores/user'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { guest: true },
  },
  {
    path: '/',
    component: () => import('@/views/Layout.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/dashboard',
      },
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: { title: '仪表盘', roles: ['ADMIN'] },
      },
      {
        path: 'articles',
        name: 'ArticleList',
        component: () => import('@/views/ArticleList.vue'),
        meta: { title: '文章列表' },
      },
      {
        path: 'search',
        name: 'Search',
        component: () => import('@/views/Search.vue'),
        meta: { title: '全文搜索' },
      },
      {
        path: 'articles/create',
        name: 'ArticleCreate',
        component: () => import('@/views/ArticleEdit.vue'),
        meta: { title: '创建文章', roles: ['ADMIN', 'EDITOR'] },
      },
      {
        path: 'articles/:id/edit',
        name: 'ArticleEdit',
        component: () => import('@/views/ArticleEdit.vue'),
        meta: { title: '编辑文章', roles: ['ADMIN', 'EDITOR'] },
      },
      {
        path: 'articles/:id',
        name: 'ArticleDetail',
        component: () => import('@/views/ArticleDetail.vue'),
        meta: { title: '文章详情' },
      },
      {
        path: 'categories',
        name: 'Categories',
        component: () => import('@/views/CategoryManage.vue'),
        meta: { title: '分类管理', roles: ['ADMIN', 'EDITOR'] },
      },
      {
        path: 'tags',
        name: 'Tags',
        component: () => import('@/views/TagManage.vue'),
        meta: { title: '标签管理', roles: ['ADMIN', 'EDITOR'] },
      },
      {
        path: 'users',
        name: 'Users',
        component: () => import('@/views/UserManage.vue'),
        meta: { title: '用户管理', roles: ['ADMIN'] },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/articles',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 全局前置守卫
router.beforeEach(async (to, _from, next) => {
  const userStore = useUserStore()

  // 首次加载时初始化用户状态
  if (!userStore.isLoggedIn && localStorage.getItem('access_token')) {
    await userStore.init()
  }

  // 已登录访问 guest 页 → 重定向
  if (to.meta.guest && userStore.isLoggedIn) {
    return next({ path: '/' })
  }

  // 需要认证但未登录 → 跳登录
  if (to.meta.requiresAuth && !userStore.isLoggedIn) {
    return next({ path: '/login', query: { redirect: to.fullPath } })
  }

  // 角色权限检查
  const requiredRoles = to.meta.roles as string[] | undefined
  if (requiredRoles && userStore.role && !requiredRoles.includes(userStore.role)) {
    // 无权限，回首页
    return next({ path: '/' })
  }

  next()
})

export default router
