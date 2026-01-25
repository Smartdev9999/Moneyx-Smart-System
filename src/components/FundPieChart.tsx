import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';

interface FundAllocation {
  id: string;
  trading_system_id: string;
  allocated_amount: number;
  current_value: number;
  profit_loss: number;
  roi_percent: number;
  trading_systems: {
    name: string;
  } | null;
}

interface FundPieChartProps {
  walletBalance: number;
  allocations: FundAllocation[];
}

const COLORS = [
  'hsl(var(--chart-1))',
  'hsl(var(--chart-2))',
  'hsl(var(--chart-3))',
  'hsl(var(--chart-4))',
  'hsl(var(--chart-5))',
];

export const FundPieChart = ({ walletBalance, allocations }: FundPieChartProps) => {
  const data = [];

  // Add wallet balance
  if (walletBalance > 0) {
    data.push({
      name: 'USDT Wallet',
      value: walletBalance,
      color: COLORS[0],
    });
  }

  // Add allocations
  allocations.forEach((allocation, index) => {
    if (allocation.current_value > 0 || allocation.allocated_amount > 0) {
      data.push({
        name: allocation.trading_systems?.name || 'Unknown System',
        value: allocation.current_value || allocation.allocated_amount,
        color: COLORS[(index + 1) % COLORS.length],
      });
    }
  });

  if (data.length === 0) {
    return (
      <div className="flex items-center justify-center h-[300px] text-muted-foreground">
        <p>ไม่มีข้อมูลการลงทุน</p>
      </div>
    );
  }

  const total = data.reduce((sum, item) => sum + item.value, 0);

  const renderCustomLabel = ({ name, value, percent }: { name: string; value: number; percent: number }) => {
    return `${(percent * 100).toFixed(1)}%`;
  };

  return (
    <div className="h-[400px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            labelLine={true}
            label={renderCustomLabel}
            outerRadius={120}
            innerRadius={60}
            fill="#8884d8"
            dataKey="value"
            paddingAngle={2}
          >
            {data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} strokeWidth={2} />
            ))}
          </Pie>
          <Tooltip 
            formatter={(value: number) => [`$${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`, '']}
            contentStyle={{
              backgroundColor: 'hsl(var(--card))',
              border: '1px solid hsl(var(--border))',
              borderRadius: '8px',
            }}
          />
          <Legend 
            verticalAlign="bottom" 
            height={36}
            formatter={(value, entry) => {
              const item = data.find(d => d.name === value);
              const percent = item ? ((item.value / total) * 100).toFixed(1) : '0';
              return (
                <span className="text-sm">
                  {value}: ${item?.value.toLocaleString('en-US', { minimumFractionDigits: 2 })} ({percent}%)
                </span>
              );
            }}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
};
