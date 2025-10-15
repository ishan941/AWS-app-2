import axios, { AxiosInstance, AxiosResponse } from 'axios'
import { HealthResponse } from '@aws-app/shared'

class ApiClient {
    private instance: AxiosInstance

    constructor() {
        this.instance = axios.create({
            baseURL: import.meta.env.VITE_API_URL || '/api',
            timeout: 10000,
            headers: {
                'Content-Type': 'application/json',
            },
        })

        // Request interceptor
        this.instance.interceptors.request.use(
            (config) => {
                console.log(`🚀 API Request: ${config.method?.toUpperCase()} ${config.url}`)
                return config
            },
            (error) => {
                console.error('❌ API Request Error:', error)
                return Promise.reject(error)
            }
        )

        // Response interceptor
        this.instance.interceptors.response.use(
            (response: AxiosResponse) => {
                console.log(`✅ API Response: ${response.status} ${response.config.url}`)
                return response
            },
            (error) => {
                console.error('❌ API Response Error:', error.response?.data || error.message)
                return Promise.reject(error)
            }
        )
    }

    // Health check endpoint
    async getHealth(): Promise<HealthResponse> {
        const response = await this.instance.get<HealthResponse>('/health')
        return response.data
    }

    // Welcome endpoint
    async getWelcome(): Promise<{ message: string }> {
        const response = await this.instance.get<{ message: string }>('/')
        return response.data
    }

    // Generic GET method
    async get<T>(url: string): Promise<T> {
        const response = await this.instance.get<T>(url)
        return response.data
    }

    // Generic POST method
    async post<T, D = any>(url: string, data?: D): Promise<T> {
        const response = await this.instance.post<T>(url, data)
        return response.data
    }

    // Generic PUT method
    async put<T, D = any>(url: string, data?: D): Promise<T> {
        const response = await this.instance.put<T>(url, data)
        return response.data
    }

    // Generic DELETE method
    async delete<T>(url: string): Promise<T> {
        const response = await this.instance.delete<T>(url)
        return response.data
    }
}

// Export singleton instance
export const apiClient = new ApiClient()
export default apiClient