export interface Account {
  amount: number;
  amountStaked: number;
  address: string;
  network: string;
  node: any;
  jailed: boolean;
  unstakingTime: Date;
  publicKey: string;
}

export interface Chain {
  id: string;
  name: string;
  url: string;
  state: number;
}
