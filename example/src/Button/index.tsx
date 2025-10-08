import { ActivityIndicator, Text, TouchableOpacity } from 'react-native';

type Props = {
  children: any;
  type?: 'info' | 'warning' | 'danger' | 'success' | 'primary' | 'grey';
  onPress: () => void;
  loading: boolean;
  outLine?: boolean;
};

export const Button = ({ children, onPress, loading = false }: Props) => {
  return (
    <TouchableOpacity
      onPress={() => {
        !loading && onPress();
      }}
    >
      {!loading && <Text>{children}</Text>}
      {loading && <ActivityIndicator color={'#FFF'} size="large" />}
    </TouchableOpacity>
  );
};
