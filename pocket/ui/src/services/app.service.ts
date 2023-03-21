const axios = require('axios');

export class AppService {
    public async getAvailableChains(): Promise<any> {
        const response = await axios.get('/api/availableChains');
        return response.data;
    }
    public async getAccount(): Promise<any> {
        const response = await axios.get('/api/account');
        return response.data;
    }
    public async getCurrentBlock(): Promise<any> {
        const response = await axios.get('/api/currentBlock');
        return response.data.height;
    }

    public async stake(stakeAmount: number, chains: string) {
        const amount = Math.floor(stakeAmount * 1000000);
        const response = await axios.post(`/api/stake`, {amount, chains});
        return response.data;
    }

    public async replaceChains(chains: string) {
        const response = await axios.post(`/api/replaceChains`, {chains});
        return response.data;
    }

    public async signMessage(message: string) {
        const response = await axios.post(`/api/signMessage`, {message});
        return response.data;
    }

}